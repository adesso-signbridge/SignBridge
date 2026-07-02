#!/usr/bin/env python3
"""
ffmpeg stitch microservice for SignBridge sign-assets worker.

Cloudflare Workers cannot run ffmpeg; point STITCH_SERVICE_URL at this service.

  brew install ffmpeg   # or apt install ffmpeg
  python3 scripts/stitch_service.py

Worker secret (sign-assets worker):
  STITCH_SERVICE_URL = http://your-host:8090

POST /stitch
  { "clipUrls": ["https://.../asl/hello.mp4", "https://.../asl/you.mp4"] }
→ video/mp4 body

Avatar-style output (default) matches the SignBridge talk screen:
  - 720x1280 portrait canvas
  - #F4F7FB talk-screen background
  - signer bottom-centered like the in-app avatar
  - 30 fps H.264 / yuv420p
  - short crossfade between signs
"""

from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any

HOST = "0.0.0.0"
PORT = 8090
MAX_CLIPS = 24
MAX_BYTES_PER_CLIP = 15 * 1024 * 1024
OUTPUT_WIDTH = 720
OUTPUT_HEIGHT = 1280
OUTPUT_FPS = 30
TRANSITION_MS = 120
BACKGROUND_COLOR = "0xF4F7FB"
AVATAR_SIGNER_WIDTH_RATIO = 0.9
VIDEO_CODEC = "libx264"
PIXEL_FORMAT = "yuv420p"
CRF = "23"
PRESET = "veryfast"


def download_clip(url: str, dest: Path) -> None:
    request = urllib.request.Request(url, method="GET")
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read(MAX_BYTES_PER_CLIP + 1)
    if len(data) > MAX_BYTES_PER_CLIP:
        raise ValueError(f"Clip too large: {url}")
    if len(data) < 256:
        raise ValueError(f"Clip empty or too small: {url}")
    dest.write_bytes(data)


def parse_options(payload: dict[str, Any]) -> dict[str, Any]:
    width = clamp_int(payload.get("width"), default=OUTPUT_WIDTH, minimum=240, maximum=1920)
    height = clamp_int(payload.get("height"), default=OUTPUT_HEIGHT, minimum=320, maximum=1920)
    fps = clamp_int(payload.get("fps"), default=OUTPUT_FPS, minimum=12, maximum=60)
    transition_ms = clamp_int(
        payload.get("transitionMs"),
        default=TRANSITION_MS,
        minimum=0,
        maximum=400,
    )
    style = str(payload.get("style") or "avatar").strip().lower()
    avatar = style in {"", "avatar", "signbridge"}
    background = str(payload.get("background") or BACKGROUND_COLOR).strip() or BACKGROUND_COLOR
    if avatar and "background" not in payload:
        background = BACKGROUND_COLOR
    return {
        "width": width,
        "height": height,
        "fps": fps,
        "transition_ms": transition_ms,
        "background": background,
        "avatar": avatar,
    }


def clamp_int(value: Any, *, default: int, minimum: int, maximum: int) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return default
    return max(minimum, min(maximum, parsed))


def probe_duration(path: Path) -> float:
    if shutil.which("ffprobe") is None:
        raise RuntimeError("ffprobe not found on PATH")

    cmd = [
        "ffprobe",
        "-v",
        "error",
        "-show_entries",
        "format=duration",
        "-of",
        "default=noprint_wrappers=1:nokey=1",
        str(path),
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout or "ffprobe failed")[-300:]
        raise RuntimeError(detail)
    try:
        return float(proc.stdout.strip())
    except ValueError as err:
        raise RuntimeError(f"Unable to read duration for {path.name}") from err


def build_video_filter(options: dict[str, Any]) -> str:
    width = options["width"]
    height = options["height"]
    fps = options["fps"]
    background = options["background"]
    if options.get("avatar"):
        signer_w = max(240, int(width * AVATAR_SIGNER_WIDTH_RATIO))
        return (
            f"fps={fps},"
            f"scale={signer_w}:-2:force_original_aspect_ratio=decrease,"
            f"pad={width}:{height}:(ow-iw)/2:oh-ih:{background},"
            "setsar=1"
        )
    return (
        f"fps={fps},"
        f"scale={width}:{height}:force_original_aspect_ratio=decrease,"
        f"pad={width}:{height}:(ow-iw)/2:(oh-ih)/2:{background},"
        "setsar=1"
    )


def normalize_clip(input_path: Path, output_path: Path, *, options: dict[str, Any]) -> None:
    if shutil.which("ffmpeg") is None:
        raise RuntimeError("ffmpeg not found on PATH")

    vf = build_video_filter(options)

    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        str(input_path),
        "-an",
        "-vf",
        vf,
        "-c:v",
        VIDEO_CODEC,
        "-preset",
        PRESET,
        "-crf",
        CRF,
        "-pix_fmt",
        PIXEL_FORMAT,
        str(output_path),
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout or "ffmpeg normalize failed")[-500:]
        raise RuntimeError(detail)


def stitch_with_ffmpeg(inputs: list[Path], output: Path, *, options: dict[str, Any]) -> None:
    if shutil.which("ffmpeg") is None:
        raise RuntimeError("ffmpeg not found on PATH")

    if len(inputs) == 1:
        normalize_clip(inputs[0], output, options=options)
        return

    transition_ms = options["transition_ms"]
    vf = build_video_filter(options)

    durations = [probe_duration(path) for path in inputs]
    normalized_inputs: list[Path] = []
    for index, path in enumerate(inputs):
        normalized = output.parent / f"normalized_{index:03d}.mp4"
        normalize_clip(path, normalized, options=options)
        normalized_inputs.append(normalized)

    if transition_ms <= 0:
        list_file = output.with_suffix(".txt")
        lines = []
        for path in normalized_inputs:
            escaped = str(path).replace("'", "'\\''")
            lines.append(f"file '{escaped}'")
        list_file.write_text("\n".join(lines) + "\n", encoding="utf-8")

        cmd = [
            "ffmpeg",
            "-y",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            str(list_file),
            "-c:v",
            VIDEO_CODEC,
            "-preset",
            PRESET,
            "-crf",
            CRF,
            "-pix_fmt",
            PIXEL_FORMAT,
            "-an",
            str(output),
        ]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        list_file.unlink(missing_ok=True)
        if proc.returncode != 0:
            detail = (proc.stderr or proc.stdout or "ffmpeg concat failed")[-500:]
            raise RuntimeError(detail)
        return

    transition_s = transition_ms / 1000.0
    offsets = []
    running_time = durations[0]
    for duration in durations[1:]:
        running_time -= transition_s
        offsets.append(max(0.0, running_time))
        running_time += duration

    cmd = ["ffmpeg", "-y"]
    for path in normalized_inputs:
        cmd.extend(["-i", str(path)])

    filter_parts = []
    for index in range(len(normalized_inputs)):
        filter_parts.append(
            f"[{index}:v]format={PIXEL_FORMAT},{vf}[v{index}]"
        )

    previous_label = "v0"
    for index in range(1, len(normalized_inputs)):
        out_label = f"vx{index}"
        offset = offsets[index - 1]
        filter_parts.append(
            f"[{previous_label}][v{index}]xfade=transition=fade:duration={transition_s}:offset={offset}[{out_label}]"
        )
        previous_label = out_label

    cmd.extend(
        [
            "-filter_complex",
            ";".join(filter_parts),
            "-map",
            f"[{previous_label}]",
            "-c:v",
            VIDEO_CODEC,
            "-preset",
            PRESET,
            "-crf",
            CRF,
            "-pix_fmt",
            PIXEL_FORMAT,
            "-an",
            str(output),
        ]
    )
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout or "ffmpeg xfade failed")[-700:]
        raise RuntimeError(detail)


class StitchHandler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args) -> None:
        print(f"[stitch] {self.address_string()} - {format % args}")

    def do_GET(self) -> None:
        if self.path.rstrip("/") == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"ok":true}')
            return
        self.send_error(404)

    def do_POST(self) -> None:
        if self.path.rstrip("/") != "/stitch":
            self.send_error(404)
            return

        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0 or length > 1_000_000:
            self.send_error(400, "Invalid body size")
            return

        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
            clip_urls = payload.get("clipUrls") or []
            if not isinstance(clip_urls, list) or not clip_urls:
                raise ValueError("clipUrls array required")
            if len(clip_urls) > MAX_CLIPS:
                raise ValueError(f"Too many clips (max {MAX_CLIPS})")
            options = parse_options(payload)

            with tempfile.TemporaryDirectory(prefix="signbridge-stitch-") as tmp:
                tmp_path = Path(tmp)
                inputs: list[Path] = []
                for index, url in enumerate(clip_urls):
                    if not isinstance(url, str) or not url.startswith("http"):
                        raise ValueError(f"Invalid clip URL at index {index}")
                    dest = tmp_path / f"clip_{index:03d}.mp4"
                    download_clip(url, dest)
                    inputs.append(dest)

                output = tmp_path / "stitched.mp4"
                stitch_with_ffmpeg(inputs, output, options=options)
                data = output.read_bytes()

            self.send_response(200)
            self.send_header("Content-Type", "video/mp4")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except urllib.error.HTTPError as err:
            self.send_error(502, f"Download failed: {err}")
        except Exception as err:
            body = json.dumps({"error": str(err)}).encode("utf-8")
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)


def main() -> None:
    server = HTTPServer((HOST, PORT), StitchHandler)
    print(f"SignBridge stitch service on http://{HOST}:{PORT}")
    print("POST /stitch  { clipUrls: [...] }  → video/mp4")
    print(
        "Defaults:"
        f" {OUTPUT_WIDTH}x{OUTPUT_HEIGHT}, {OUTPUT_FPS}fps,"
        f" avatar background={BACKGROUND_COLOR}, transition={TRANSITION_MS}ms"
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
