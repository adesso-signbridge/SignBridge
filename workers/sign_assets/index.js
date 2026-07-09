/**
 * Serves signer video clips from R2 for in-app avatar playback.
 *
 * GET  /asl/{token}.mp4
 * GET  /isl/{token}.mp4
 * GET  /manifest.json
 * POST /clips  { "paths": ["isl/hello.mp4", ...] } → signed playback URLs
 *
 * Bucket: signbridge-sign-videos (see wrangler.sign-assets.toml)
 */

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, HEAD, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Range, Content-Type",
  "Access-Control-Expose-Headers": "Content-Length, Content-Range, Accept-Ranges",
};

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS });
    }

    const url = new URL(request.url);
    const pathname = decodeURIComponent(url.pathname).replace(/^\/+/, "");

    if (request.method === "POST" && (pathname === "clips" || pathname === "")) {
      return handleClipsPost(request, url);
    }

    if (request.method !== "GET" && request.method !== "HEAD") {
      return json({ error: "Method not allowed" }, 405);
    }

    const key = pathname;
    if (!key || key.includes("..")) {
      return json({ error: "Not found" }, 404);
    }

    const rangeHeader = request.headers.get("Range");
    const headOnly = request.method === "HEAD";

    if (!rangeHeader) {
      const object = await env.SIGN_VIDEOS.get(key);
      if (!object) {
        return json({ error: "Not found" }, 404);
      }
      const headers = objectHeaders(object, key);
      if (headOnly) {
        return new Response(null, { status: 200, headers });
      }
      return new Response(object.body, { status: 200, headers });
    }

    const size = await objectSize(env, key);
    if (size == null) {
      return json({ error: "Not found" }, 404);
    }

    const range = parseRange(rangeHeader, size);
    if (!range) {
      return new Response("Invalid Range", { status: 416, headers: CORS });
    }

    const object = await env.SIGN_VIDEOS.get(key, {
      range: { offset: range.start, length: range.length },
    });
    if (!object) {
      return json({ error: "Not found" }, 404);
    }

    const headers = objectHeaders(object, key);
    headers.set(
      "Content-Range",
      `bytes ${range.start}-${range.end}/${size}`,
    );
    headers.set("Content-Length", String(range.length));

    if (headOnly) {
      return new Response(null, { status: 206, headers });
    }
    return new Response(object.body, { status: 206, headers });
  },
};

async function handleClipsPost(request, url) {
  let body;
  try {
    body = await request.json();
  } catch (_) {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const paths = Array.isArray(body.paths)
    ? body.paths
    : Array.isArray(body.assetPaths)
      ? body.assetPaths
      : [];

  if (paths.length === 0) {
    return json({ error: "Missing paths array" }, 400);
  }

  const origin = url.origin;
  const clips = [];
  for (const rawPath of paths) {
    const key = normalizeClipKey(rawPath);
    if (!key) {
      continue;
    }
    clips.push({
      key,
      assetPath: toBundledAssetPath(key),
      url: `${origin}/${key}`,
    });
  }

  if (clips.length === 0) {
    return json({ error: "No valid clip paths" }, 400);
  }

  return json({ ok: true, clips });
}

function normalizeClipKey(rawPath) {
  const trimmed = String(rawPath || "").trim();
  if (!trimmed || trimmed.includes("..")) {
    return null;
  }

  const withoutQuery = trimmed.split("?")[0];
  if (withoutQuery.startsWith("http://") || withoutQuery.startsWith("https://")) {
    try {
      return normalizeClipKey(new URL(withoutQuery).pathname);
    } catch (_) {
      return null;
    }
  }

  const stripped = withoutQuery
    .replace(/^\/+/, "")
    .replace(/^assets\/signs\//, "");

  if (!/^(asl|isl)\/.+\.mp4$/i.test(stripped)) {
    return null;
  }
  return stripped;
}

function toBundledAssetPath(key) {
  return `assets/signs/${key}`;
}

async function objectSize(env, key) {
  const meta = await env.SIGN_VIDEOS.head(key);
  return meta?.size ?? null;
}

function objectHeaders(object, key) {
  const headers = new Headers(CORS);
  object.writeHttpMetadata(headers);
  headers.set("Accept-Ranges", "bytes");
  if (!headers.has("Content-Type")) {
    headers.set(
      "Content-Type",
      key.endsWith(".json") ? "application/json" : "video/mp4",
    );
  }
  headers.set("Cache-Control", "public, max-age=86400");
  return headers;
}

function parseRange(rangeHeader, size) {
  const match = /^bytes=(\d*)-(\d*)$/.exec(rangeHeader.trim());
  if (!match || size <= 0) {
    return null;
  }

  let start = match[1] ? Number.parseInt(match[1], 10) : 0;
  let end = match[2] ? Number.parseInt(match[2], 10) : size - 1;

  if (Number.isNaN(start) || Number.isNaN(end) || start > end || start >= size) {
    return null;
  }
  end = Math.min(end, size - 1);
  return {
    start,
    end,
    length: end - start + 1,
  };
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}
