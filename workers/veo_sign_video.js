/**
 * Veo 3.1 sign-video generation (Adobe Firefly-style text-to-video).
 * Uses Gemini predictLongRunning; caches MP4 output in R2.
 */

const GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta";
const VEO_PREFIX = "generated/veo-v1/";
const MAX_GLOSS_TOKENS = 16;

export function veoModel(env) {
  return (env.VEO_MODEL || "veo-3.1-fast-generate-preview").trim();
}

export function signAssetsPublicOrigin(env) {
  return (
    env.SIGN_ASSETS_PUBLIC_URL ||
    "https://signbridge-sign-assets.signbridge-adesso.workers.dev"
  )
    .trim()
    .replace(/\/+$/, "");
}

export function geminiApiKey(env) {
  return env.GEMINI_KEY || env.GEMINI_API_KEY || "";
}

export function avatarGenerationMode(env, requestedMode = "") {
  const mode = `${requestedMode || env.VEO_AVATAR_MODE || "genasl"}`
    .trim()
    .toLowerCase();
  return mode || "genasl";
}

export function buildSignVideoPrompt({
  caption,
  glossSequence,
  signLanguage,
  avatarMode = "genasl",
}) {
  const glosses = normalizeGlossList(glossSequence);
  const phrase = glosses.length > 0 ? glosses.join(" ") : `${caption || ""}`.trim();
  const languageLabel = `${signLanguage || "ASL"}`.toUpperCase().includes("ISL")
    ? "Indian Sign Language (ISL)"
    : "American Sign Language (ASL)";
  const trimmedCaption = `${caption || ""}`.trim();
  const mode = avatarMode.trim().toLowerCase();

  const signingInstruction =
    mode === "genasl"
      ? buildGenAslPrompt({ phrase, glosses, languageLabel, trimmedCaption })
      : `Sign the gloss sequence: ${phrase}.`;

  return [
    `Portrait video of a professional deaf signer performing ${languageLabel}.`,
    signingInstruction,
    "Clean light gray studio background, signer centered from waist up,",
    "natural expressive signing motion, no spoken dialogue, signing only,",
    "realistic human hands and face, stable camera, soft even lighting.",
  ].join(" ");
}

function buildGenAslPrompt({ phrase, glosses, languageLabel, trimmedCaption }) {
  if (glosses.length > 0) {
    return (
      `Use a GenASL-style gloss-first workflow for ${languageLabel}. ` +
      `Follow this gloss sequence exactly as the signing plan: ${phrase}. ` +
      `If a word has no exact lexical sign, fingerspell only that word while preserving natural signing flow.`
    );
  }

  if (trimmedCaption) {
    return (
      `Use a GenASL-style workflow for ${languageLabel}. ` +
      `Translate the spoken phrase into accurate signing: "${trimmedCaption}". ` +
      `Prefer canonical sign choices and fingerspell unknown names or missing words only.`
    );
  }

  return `Use a GenASL-style workflow for ${languageLabel}. Sign naturally and clearly.`;
}

export function veoParameters(env, { seed } = {}) {
  return {
    aspectRatio: (env.VEO_ASPECT_RATIO || "9:16").trim(),
    resolution: (env.VEO_RESOLUTION || "720p").trim(),
    durationSeconds: clampInt(env.VEO_DURATION_SECONDS, 8, 4, 8),
    sampleCount: 1,
    ...(Number.isFinite(seed) ? { seed } : {}),
  };
}

export async function resolveVeoSignVideo(env, options) {
  const {
    caption = "",
    glossSequence = [],
    signLanguage = "ASL",
    jobId = "",
    operationName = "",
    avatarMode = "",
  } = options;

  const prompt = buildSignVideoPrompt({
    caption,
    glossSequence,
    signLanguage,
    avatarMode: avatarGenerationMode(env, avatarMode),
  });
  const seed = seedFromJob(jobId);
  const parameters = veoParameters(env, { seed });
  const cacheKey = `${VEO_PREFIX}${await hashPayload(prompt, parameters)}.mp4`;
  const publicOrigin = signAssetsPublicOrigin(env);

  const cached = await env.SIGN_VIDEOS.head(cacheKey);
  if (cached) {
    return {
      ok: true,
      status: "ready",
      cached: true,
      videoUrl: `${publicOrigin}/${cacheKey}`,
      cacheKey,
      prompt,
      model: veoModel(env),
      jobId,
    };
  }

  if (operationName) {
    return pollVeoOperation(env, {
      operationName,
      cacheKey,
      publicOrigin,
      prompt,
      jobId,
    });
  }

  return startVeoOperation(env, {
    prompt,
    parameters,
    cacheKey,
    publicOrigin,
    jobId,
  });
}

async function startVeoOperation(env, { prompt, parameters, cacheKey, publicOrigin, jobId }) {
  const apiKey = geminiApiKey(env);
  if (!apiKey) {
    throw new Error("GEMINI_KEY not configured for Veo video generation");
  }

  const model = veoModel(env);
  const url = `${GEMINI_BASE}/models/${encodeURIComponent(model)}:predictLongRunning`;

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey,
    },
    body: JSON.stringify({
      instances: [{ prompt }],
      parameters,
    }),
  });

  const data = await readJson(res);
  if (!res.ok) {
    throw new Error(formatGeminiError(data, res.status));
  }

  const operation = `${data.name || ""}`.trim();
  if (!operation) {
    throw new Error("Veo did not return an operation name");
  }

  return {
    ok: true,
    status: "processing",
    operationName: operation,
    cacheKey,
    videoUrl: null,
    prompt,
    model,
    jobId,
    pollAfterMs: 8000,
  };
}

async function pollVeoOperation(env, { operationName, cacheKey, publicOrigin, prompt, jobId }) {
  const apiKey = geminiApiKey(env);
  const operationPath = operationName.startsWith("operations/")
    ? operationName
    : `operations/${operationName}`;

  const res = await fetch(`${GEMINI_BASE}/${operationPath}`, {
    headers: { "x-goog-api-key": apiKey },
  });

  const data = await readJson(res);
  if (!res.ok) {
    throw new Error(formatGeminiError(data, res.status));
  }

  if (!data.done) {
    return {
      ok: true,
      status: "processing",
      operationName,
      cacheKey,
      videoUrl: null,
      prompt,
      model: veoModel(env),
      jobId,
      pollAfterMs: 8000,
    };
  }

  if (data.error) {
    throw new Error(JSON.stringify(data.error).slice(0, 300));
  }

  const videoUri =
    data.response?.generateVideoResponse?.generatedSamples?.[0]?.video?.uri ||
    data.response?.generatedVideos?.[0]?.video?.uri ||
    null;

  if (!videoUri) {
    throw new Error("Veo operation completed without a video URI");
  }

  const videoRes = await fetch(videoUri, {
    headers: { "x-goog-api-key": apiKey },
  });
  if (!videoRes.ok) {
    throw new Error(`Veo download failed (${videoRes.status})`);
  }

  const bytes = await videoRes.arrayBuffer();
  if (!bytes || bytes.byteLength < 1024) {
    throw new Error("Veo returned an empty video");
  }

  await env.SIGN_VIDEOS.put(cacheKey, bytes, {
    httpMetadata: {
      contentType: "video/mp4",
      cacheControl: "public, max-age=604800",
    },
  });

  return {
    ok: true,
    status: "ready",
    cached: false,
    operationName,
    cacheKey,
    videoUrl: `${publicOrigin}/${cacheKey}`,
    prompt,
    model: veoModel(env),
    jobId,
  };
}

function normalizeGlossList(raw) {
  if (!Array.isArray(raw)) {
    return [];
  }
  const tokens = [];
  for (const item of raw.slice(0, MAX_GLOSS_TOKENS)) {
    const trimmed = `${item || ""}`.trim().toUpperCase();
    if (
      trimmed &&
      trimmed !== "GLOSSSEQUENCE" &&
      trimmed !== "GLOSSEQUENCE"
    ) {
      tokens.push(trimmed);
    }
  }
  return tokens;
}

function clampInt(value, fallback, min, max) {
  const parsed = Number.parseInt(`${value ?? ""}`, 10);
  if (Number.isNaN(parsed)) {
    return fallback;
  }
  return Math.max(min, Math.min(max, parsed));
}

function seedFromJob(jobId) {
  const trimmed = `${jobId || ""}`.trim();
  if (!trimmed) {
    return undefined;
  }
  let hash = 0;
  for (let index = 0; index < trimmed.length; index++) {
    hash = (hash * 31 + trimmed.charCodeAt(index)) >>> 0;
  }
  return hash % 999_999;
}

async function hashPayload(prompt, parameters) {
  const payload = JSON.stringify({ prompt, parameters });
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(payload),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function readJson(res) {
  try {
    return await res.json();
  } catch (_) {
    return {};
  }
}

function formatGeminiError(data, status) {
  const message =
    data?.error?.message ||
    data?.error ||
    data?.detail ||
    `Gemini Veo request failed (${status})`;
  return `${message}`.slice(0, 300);
}
