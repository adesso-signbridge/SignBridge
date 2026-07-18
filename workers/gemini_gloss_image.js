/**
 * Nano Banana (Gemini image) 2D sign illustrations — one image per gloss.
 * Uses generateContent; caches PNG output in R2.
 */

const GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta";
const IMAGE_PREFIX = "generated/banana-v1/";
const MAX_GLOSS_TOKENS = 16;
const DEFAULT_CONCURRENCY = 3;

export function bananaImageModel(env) {
  return (
    env.BANANA_IMAGE_MODEL ||
    env.GEMINI_IMAGE_MODEL ||
    "gemini-2.5-flash-image"
  ).trim();
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

export function buildGlossImagePrompt({ gloss, signLanguage }) {
  const token = `${gloss || ""}`.trim().toUpperCase() || "SIGN";
  const languageLabel = `${signLanguage || "ASL"}`.toUpperCase().includes("ISL")
    ? "Indian Sign Language (ISL)"
    : "American Sign Language (ASL)";

  return [
    `2D illustration of a professional deaf signer performing ${languageLabel}.`,
    `The gloss being signed is: ${token}.`,
    "Single clear still frame, waist-up portrait, clean light gray studio background,",
    "natural expressive handshape and facial expression for that gloss,",
    "no text, no captions, no watermark labels, realistic hands and face,",
    "soft even lighting, centered composition, educational sign-language style.",
  ].join(" ");
}

export function bananaImageConfig(env) {
  return {
    aspectRatio: (env.BANANA_ASPECT_RATIO || "3:4").trim(),
  };
}

export async function resolveGlossImages(env, options) {
  const {
    glossSequence = [],
    signLanguage = "ASL",
    jobId = "",
  } = options;

  const glosses = normalizeGlossList(glossSequence);
  if (glosses.length === 0) {
    throw new Error("Missing glossSequence");
  }

  const apiKey = geminiApiKey(env);
  if (!apiKey) {
    throw new Error("GEMINI_KEY not configured for Banana image generation");
  }

  if (!env.SIGN_VIDEOS) {
    throw new Error("SIGN_VIDEOS R2 binding not configured");
  }

  const model = bananaImageModel(env);
  const imageConfig = bananaImageConfig(env);
  const publicOrigin = signAssetsPublicOrigin(env);
  const concurrency = clampInt(
    env.BANANA_IMAGE_CONCURRENCY,
    DEFAULT_CONCURRENCY,
    1,
    6,
  );

  const images = await mapPool(glosses, concurrency, async (gloss) => {
    const prompt = buildGlossImagePrompt({ gloss, signLanguage });
    const cacheKey = `${IMAGE_PREFIX}${await hashPayload(prompt, {
      model,
      ...imageConfig,
    })}.png`;

    const cached = await env.SIGN_VIDEOS.head(cacheKey);
    if (cached) {
      return {
        gloss,
        imageUrl: `${publicOrigin}/${cacheKey}`,
        cacheKey,
        cached: true,
        prompt,
      };
    }

    const { bytes, mimeType } = await generateBananaImage(env, {
      apiKey,
      model,
      prompt,
      imageConfig,
    });

    const contentType = mimeType || "image/png";
    const key =
      contentType.includes("jpeg") || contentType.includes("jpg")
        ? cacheKey.replace(/\.png$/i, ".jpg")
        : cacheKey;

    await env.SIGN_VIDEOS.put(key, bytes, {
      httpMetadata: {
        contentType,
        cacheControl: "public, max-age=604800",
      },
    });

    return {
      gloss,
      imageUrl: `${publicOrigin}/${key}`,
      cacheKey: key,
      cached: false,
      prompt,
    };
  });

  return {
    ok: true,
    status: "ready",
    images,
    imageUrls: images.map((item) => item.imageUrl),
    model,
    jobId,
  };
}

async function generateBananaImage(env, { apiKey, model, prompt, imageConfig }) {
  const url = `${GEMINI_BASE}/models/${encodeURIComponent(model)}:generateContent`;

  const generationConfig = {
    responseModalities: ["TEXT", "IMAGE"],
    imageConfig: {
      aspectRatio: imageConfig.aspectRatio || "3:4",
    },
  };

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey,
    },
    body: JSON.stringify({
      contents: [
        {
          role: "user",
          parts: [{ text: prompt }],
        },
      ],
      generationConfig,
    }),
  });

  const data = await readJson(res);
  if (!res.ok) {
    throw new Error(formatGeminiError(data, res.status));
  }

  const part = findInlineImagePart(data);
  if (!part?.inlineData?.data && !part?.inline_data?.data) {
    throw new Error("Banana image response missing inline image data");
  }

  const inline = part.inlineData || part.inline_data;
  const binary = base64ToBytes(inline.data);
  if (binary.byteLength < 256) {
    throw new Error("Banana returned an empty image");
  }

  return {
    bytes: binary,
    mimeType: inline.mimeType || inline.mime_type || "image/png",
  };
}

function base64ToBytes(base64) {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function findInlineImagePart(data) {
  const parts = data?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) {
    return null;
  }
  for (const part of parts) {
    if (part?.inlineData?.data || part?.inline_data?.data) {
      return part;
    }
  }
  return null;
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

async function mapPool(items, concurrency, mapper) {
  const results = new Array(items.length);
  let nextIndex = 0;

  async function worker() {
    while (nextIndex < items.length) {
      const index = nextIndex;
      nextIndex += 1;
      results[index] = await mapper(items[index], index);
    }
  }

  const workers = Array.from(
    { length: Math.min(concurrency, items.length) },
    () => worker(),
  );
  await Promise.all(workers);
  return results;
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
    `Gemini Banana request failed (${status})`;
  return `${message}`.slice(0, 300);
}
