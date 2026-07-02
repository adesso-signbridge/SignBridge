/**
 * Stitch gloss clip sequence into one MP4 (R2 cache + optional ffmpeg service).
 */

import {
  parseManifest,
  resolveGlossClipPaths,
} from "./gloss_clip_resolver.js";

const STITCH_PREFIX = "stitched/avatar-v1/";
const MAX_STITCH_CLIPS = 24;

export async function loadManifestFromR2(env) {
  const object = await env.SIGN_VIDEOS.get("manifest.json");
  if (!object) {
    throw new Error("manifest.json not found in R2");
  }
  const text = await object.text();
  const manifest = JSON.parse(text);
  parseManifest(manifest);
  return manifest;
}

export async function stitchGlossSequence(env, options) {
  const {
    glossSequence,
    signLanguage,
    origin,
    jobId = "",
    manifest: providedManifest,
  } = options;

  const glosses = Array.isArray(glossSequence) ? glossSequence : [];
  if (glosses.length === 0) {
    throw new Error("glossSequence is empty");
  }
  if (glosses.length > MAX_STITCH_CLIPS) {
    throw new Error(`Too many gloss tokens (max ${MAX_STITCH_CLIPS})`);
  }

  const manifest =
    providedManifest || (await loadManifestFromR2(env));
  const { keys, assetPaths, missing } = resolveGlossClipPaths(
    manifest,
    signLanguage,
    glosses,
  );

  if (keys.length === 0) {
    throw new Error(
      `No R2 clips for gloss sequence (missing: ${missing.slice(0, 5).join(", ")})`,
    );
  }

  const cacheKey = `${STITCH_PREFIX}${await hashClipKeys(keys)}.mp4`;
  const cached = await env.SIGN_VIDEOS.head(cacheKey);
  if (cached) {
    return {
      ok: true,
      cached: true,
      videoUrl: `${origin}/${cacheKey}`,
      cacheKey,
      clipKeys: keys,
      assetPaths,
      missing,
      jobId,
    };
  }

  const stitchedBytes = await buildStitchedMp4(env, keys, origin);
  await env.SIGN_VIDEOS.put(cacheKey, stitchedBytes, {
    httpMetadata: {
      contentType: "video/mp4",
      cacheControl: "public, max-age=604800",
    },
  });

  return {
    ok: true,
    cached: false,
    videoUrl: `${origin}/${cacheKey}`,
    cacheKey,
    clipKeys: keys,
    assetPaths,
    missing,
    jobId,
  };
}

async function buildStitchedMp4(env, keys, origin) {
  const stitchServiceUrl = (env.STITCH_SERVICE_URL || "").trim();
  if (stitchServiceUrl) {
    const clipUrls = keys.map((key) => `${origin}/${key}`);
    return stitchViaService(stitchServiceUrl, clipUrls);
  }

  if (keys.length === 1) {
    const object = await env.SIGN_VIDEOS.get(keys[0]);
    if (!object) {
      throw new Error(`Clip not found in R2: ${keys[0]}`);
    }
    return object.arrayBuffer();
  }

  throw new Error(
    "Multi-clip avatar stitch requires STITCH_SERVICE_URL (deploy scripts/stitch_service.py)",
  );
}

async function stitchViaService(serviceUrl, clipUrls) {
  const res = await fetch(serviceUrl.replace(/\/+$/, "") + "/stitch", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      clipUrls,
      style: "avatar",
      background: "0xF4F7FB",
      width: 720,
      height: 1280,
      fps: 30,
      transitionMs: 120,
    }),
  });

  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`Stitch service ${res.status}: ${detail.slice(0, 200)}`);
  }

  const contentType = res.headers.get("Content-Type") || "";
  if (!contentType.includes("video") && !contentType.includes("octet-stream")) {
    const detail = await res.text();
    throw new Error(`Stitch service returned non-video: ${detail.slice(0, 120)}`);
  }

  const bytes = await res.arrayBuffer();
  if (!bytes || bytes.byteLength < 1024) {
    throw new Error("Stitch service returned empty video");
  }
  return bytes;
}

async function hashClipKeys(keys) {
  const payload = keys.join("|");
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(payload),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
