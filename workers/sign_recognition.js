/**
 * Shared sign video → gloss → spoken text handler for Cloudflare Workers.
 *
 * Stage 1: video → glossSequence[] (one token per sign, in order)
 * Stage 2: glossSequence → natural spoken text
 *
 * Gemini: gemini-3.5-flash only for both stages (see geminiSignVideoOnlyChain).
 */

import { geminiSignVideoOnlyChain } from "./gemini_model_chain.js";

const JSON_HEADERS = { "Content-Type": "application/json" };
const MAX_VIDEO_BYTES = 20 * 1024 * 1024;

const JSON_ARTIFACT_TOKENS = new Set(["GLOSSSEQUENCE", "GLOSSEQUENCE"]);

export async function handleSignRecognitionRequest(request, env) {
  if (request.method === "OPTIONS") {
    return signJson({}, 204);
  }

  if (request.method !== "POST") {
    return signJson({ error: "Method not allowed" }, 405);
  }

  if (env.WORKER_SHARED_KEY) {
    const provided = request.headers.get("X-SignBridge-Key");
    if (provided !== env.WORKER_SHARED_KEY) {
      return signJson({ error: "Unauthorized" }, 401);
    }
  }

  let form;
  try {
    form = await request.formData();
  } catch (_) {
    return signJson({ error: "Expected multipart form data" }, 400);
  }

  const video = form.get("video");
  const languageCode = (form.get("languageCode") || "ENG").toString().trim();
  const signLanguage = (form.get("signLanguage") || "ASL").toString().trim();
  const jobId = (form.get("jobId") || crypto.randomUUID()).toString().trim();
  const durationMs = Number(form.get("durationMs") || 0);

  if (!(video instanceof File)) {
    return signJson({ error: "Missing video file" }, 400);
  }

  const bytes = await video.arrayBuffer();
  if (!bytes || bytes.byteLength === 0) {
    return signJson({ error: "Empty video upload" }, 400);
  }
  if (bytes.byteLength > MAX_VIDEO_BYTES) {
    return signJson({ error: "Video too large (max 20 MB)" }, 413);
  }

  const mimeType = resolveVideoMimeType(video);

  const safeDurationMs =
    Number.isFinite(durationMs) && durationMs > 0 ? durationMs : 0;

  let text;
  let glossSequence;
  let modelUsed;
  try {
    ({ text, glossSequence, modelUsed } = await videoToSpokenText(
      bytes,
      mimeType,
      languageCode,
      signLanguage,
      safeDurationMs,
      env,
    ));
  } catch (err) {
    return signJson(
      {
        error: "Sign recognition failed",
        detail: String(err).slice(0, 300),
        jobId,
      },
      502,
    );
  }

  return signJson({
    ok: true,
    jobId,
    text,
    glossSequence,
    modelUsed,
    durationMs: Number.isFinite(durationMs) ? durationMs : 0,
  });
}

function resolveVideoMimeType(video) {
  const type = (video.type || "").trim().toLowerCase();
  if (type.startsWith("video/")) {
    return type;
  }

  const name = typeof video.name === "string" ? video.name.toLowerCase() : "";
  if (name.endsWith(".mov")) {
    return "video/quicktime";
  }
  if (name.endsWith(".webm")) {
    return "video/webm";
  }
  return "video/mp4";
}

function geminiApiKey(env) {
  return env.GEMINI_KEY || env.GEMINI_API_KEY || "";
}

function geminiModels(env) {
  return geminiSignVideoOnlyChain(env);
}

function geminiTextModels(env) {
  return geminiSignVideoOnlyChain(env);
}

function isRetryableGeminiStatus(status) {
  return status === 429 || status === 500 || status === 503 || status === 504;
}

function isModelUnavailableStatus(status) {
  return status === 404 || status === 400;
}

function shouldFailOverSignModel(err) {
  const status = err.status || 0;
  return isModelUnavailableStatus(status) || status === 429;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function spokenLanguageName(languageCode) {
  switch (languageCode.trim().toUpperCase()) {
    case "HI":
      return "Hindi";
    case "TA":
      return "Tamil";
    case "ML":
      return "Malayalam";
    default:
      return "English";
  }
}

function signDurationSeconds(durationMs) {
  if (!durationMs || durationMs <= 0) {
    return 0;
  }
  return Math.max(1, Math.round(durationMs / 1000));
}

function expectedSignCount(durationMs) {
  const seconds = signDurationSeconds(durationMs);
  if (seconds <= 0) {
    return null;
  }
  return Math.max(1, Math.min(12, Math.round(seconds / 1.5)));
}

function signGlossSystemInstruction(signLanguage, durationMs) {
  const sign = signLanguage.trim().toUpperCase();
  const expected = expectedSignCount(durationMs);
  const seconds = signDurationSeconds(durationMs);
  const durationHint =
    seconds > 0
      ? `The clip is about ${seconds} second(s). Expect roughly ${expected ?? "several"} distinct signs. `
      : "";
  return (
    `You identify individual signs in ${sign} sign-language video. ` +
    durationHint +
    `Return JSON only: {"glossSequence":["TOKEN","..."]}. ` +
    `Rules: ` +
    `• ONE array entry per distinct sign, in chronological order. ` +
    `• UPPERCASE gloss tokens (e.g. ME, WANT, WATER, NAME, HELLO). ` +
    `• Include EVERY sign you can identify—do not stop after the first sign. ` +
    `• Do not merge multiple signs into one token unless they are fingerspelled as one word. ` +
    `• Do not return English sentences—gloss tokens only. ` +
    `• Do not describe hands, camera, or scene. ` +
    `• If nothing clear was signed, return {"glossSequence":[]}.`
  );
}

function signGlossUserPrompt(signLanguage, durationMs) {
  const seconds = signDurationSeconds(durationMs);
  const expected = expectedSignCount(durationMs);
  const durationHint =
    expected != null && seconds >= 2
      ? ` List each of the ~${expected} signs separately in order.`
      : "";
  return (
    `Watch this ${signLanguage.trim()} signing video. ` +
    `Output one gloss token per sign in the order performed.${durationHint}`
  );
}

function glossToTextSystemInstruction(signLanguage, languageCode) {
  const sign = signLanguage.trim().toUpperCase();
  const spoken = spokenLanguageName(languageCode);
  return (
    `You convert ${sign} sign gloss tokens into natural ${spoken} speech. ` +
    `Return JSON only: {"text":"..."}. ` +
    `Use ALL gloss tokens in order to build the full meaning. ` +
    `Write what the signer meant to say in ${spoken}, not a scene description. ` +
    `Use correct ${spoken} grammar. One or more complete sentences.`
  );
}

function glossToTextUserPrompt(glossSequence, signLanguage, languageCode) {
  const spoken = spokenLanguageName(languageCode);
  return (
    `Sign language: ${signLanguage.trim()}\n` +
    `Gloss sequence (one sign each, in order): ${glossSequence.join(" ")}\n` +
    `Write the full ${spoken} sentence(s) the signer intended.`
  );
}

const SIGN_GLOSS_RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    glossSequence: {
      type: "ARRAY",
      items: { type: "STRING" },
      description:
        "One UPPERCASE gloss token per distinct sign, chronological order.",
    },
  },
  required: ["glossSequence"],
  propertyOrdering: ["glossSequence"],
};

const SIGN_TEXT_RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    text: {
      type: "STRING",
      description: "Natural spoken-language translation of the gloss sequence.",
    },
  },
  required: ["text"],
  propertyOrdering: ["text"],
};

async function videoToSpokenText(
  bytes,
  mimeType,
  languageCode,
  signLanguage,
  durationMs,
  env,
) {
  const apiKey = geminiApiKey(env);
  if (!apiKey) {
    throw new Error("GEMINI_KEY not configured");
  }

  const { glossSequence, glossModel } = await videoToGlossSequence(
    bytes,
    mimeType,
    signLanguage,
    durationMs,
    apiKey,
    env,
  );

  if (!glossSequence.length) {
    throw new Error("No signs detected in video");
  }

  const { text, textModel } = await glossSequenceToSpokenText(
    glossSequence,
    languageCode,
    signLanguage,
    apiKey,
    env,
  );

  if (!text.trim()) {
    throw new Error("Gemini returned empty sign text");
  }

  return {
    text: text.trim(),
    glossSequence,
    modelUsed: `${glossModel}+${textModel}`,
  };
}

async function videoToGlossSequence(
  bytes,
  mimeType,
  signLanguage,
  durationMs,
  apiKey,
  env,
) {
  const errors = [];
  for (const model of geminiModels(env)) {
    try {
      const glossSequence = await requestGeminiSignGloss(
        model,
        bytes,
        mimeType,
        signLanguage,
        durationMs,
        apiKey,
      );
      if (!glossSequence.length) {
        throw new Error("No signs detected in video");
      }
      return { glossSequence, glossModel: model };
    } catch (err) {
      errors.push(err);
      if (shouldFailOverSignModel(err)) {
        continue;
      }
    }
  }

  const detail = errors.map((err) => String(err).slice(0, 80)).join(" | ");
  throw new Error(detail || "Gemini sign gloss failed");
}

async function requestGeminiSignGloss(
  model,
  bytes,
  mimeType,
  signLanguage,
  durationMs,
  apiKey,
) {
  let lastError = null;

  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const glossSequence = await callGeminiSignGloss(
        model,
        bytes,
        mimeType,
        signLanguage,
        durationMs,
        apiKey,
      );
      if (!glossSequence.length) {
        throw new Error("No signs detected in video");
      }
      return glossSequence;
    } catch (err) {
      lastError = err;
      const status = err.status || 0;
      if (isModelUnavailableStatus(status) || status === 429) {
        break;
      }
      if (!isRetryableGeminiStatus(status) || attempt === 2) {
        break;
      }
      await sleep(500 * (attempt + 1));
    }
  }

  throw lastError || new Error("Gemini sign gloss request failed");
}

async function callGeminiSignGloss(
  model,
  bytes,
  mimeType,
  signLanguage,
  durationMs,
  apiKey,
) {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}` +
    `:generateContent?key=${encodeURIComponent(apiKey)}`;

  const res = await fetch(url, {
    method: "POST",
    headers: JSON_HEADERS,
    body: JSON.stringify({
      systemInstruction: {
        parts: [{ text: signGlossSystemInstruction(signLanguage, durationMs) }],
      },
      contents: [
        {
          role: "user",
          parts: [
            {
              inlineData: {
                mimeType,
                data: bytesToBase64(bytes),
              },
            },
            { text: signGlossUserPrompt(signLanguage, durationMs) },
          ],
        },
      ],
      generationConfig: {
        temperature: 0.0,
        topP: 0.1,
        topK: 1,
        maxOutputTokens: 256,
        responseMimeType: "application/json",
        responseSchema: SIGN_GLOSS_RESPONSE_SCHEMA,
      },
    }),
  });

  if (!res.ok) {
    const detail = await res.text();
    const error = new Error(`Gemini ${res.status}: ${detail}`);
    error.status = res.status;
    throw error;
  }

  const data = await res.json();
  const content = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!content) {
    throw new Error("Gemini returned empty sign gloss response");
  }

  return parseGlossSequence(content);
}

async function glossSequenceToSpokenText(
  glossSequence,
  languageCode,
  signLanguage,
  apiKey,
  env,
) {
  const errors = [];
  for (const model of geminiTextModels(env)) {
    let lastError = null;

    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        const text = await callGeminiGlossToText(
          model,
          glossSequence,
          languageCode,
          signLanguage,
          apiKey,
        );
        if (!text.trim()) {
          throw new Error("Gemini returned empty sign text");
        }
        return { text: text.trim(), textModel: model };
      } catch (err) {
        lastError = err;
        const status = err.status || 0;
        if (isModelUnavailableStatus(status) || status === 429) {
          break;
        }
        if (!isRetryableGeminiStatus(status) || attempt === 2) {
          break;
        }
        await sleep(400 * (attempt + 1));
      }
    }

    if (lastError) {
      errors.push(lastError);
      if (shouldFailOverSignModel(lastError)) {
        continue;
      }
    }
  }

  const detail = errors.map((err) => String(err).slice(0, 80)).join(" | ");
  throw new Error(detail || "Gloss to text failed");
}

async function callGeminiGlossToText(
  model,
  glossSequence,
  languageCode,
  signLanguage,
  apiKey,
) {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}` +
    `:generateContent?key=${encodeURIComponent(apiKey)}`;

  const res = await fetch(url, {
    method: "POST",
    headers: JSON_HEADERS,
    body: JSON.stringify({
      systemInstruction: {
        parts: [
          {
            text: glossToTextSystemInstruction(signLanguage, languageCode),
          },
        ],
      },
      contents: [
        {
          role: "user",
          parts: [
            {
              text: glossToTextUserPrompt(
                glossSequence,
                signLanguage,
                languageCode,
              ),
            },
          ],
        },
      ],
      generationConfig: {
        temperature: 0.0,
        topP: 0.1,
        topK: 1,
        maxOutputTokens: 512,
        responseMimeType: "application/json",
        responseSchema: SIGN_TEXT_RESPONSE_SCHEMA,
      },
    }),
  });

  if (!res.ok) {
    const detail = await res.text();
    const error = new Error(`Gemini ${res.status}: ${detail}`);
    error.status = res.status;
    throw error;
  }

  const data = await res.json();
  const content = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!content) {
    throw new Error("Gemini returned empty gloss-to-text response");
  }

  return parseSignText(content);
}

function parseGlossSequence(content) {
  const text = String(content).trim();
  let tokens = null;

  try {
    tokens = glossTokensFromParsed(JSON.parse(text));
  } catch (_) {
    // fall through
  }

  if (!tokens) {
    const objectMatch = text.match(/\{[\s\S]*"glossSequence"[\s\S]*\}/);
    if (objectMatch) {
      try {
        tokens = glossTokensFromParsed(JSON.parse(objectMatch[0]));
      } catch (_) {
        // fall through
      }
    }
  }

  if (!tokens) {
    throw new Error(`Unable to parse gloss response: ${text.slice(0, 120)}`);
  }

  return normalizeGlossSequence(tokens);
}

function glossTokensFromParsed(parsed) {
  if (Array.isArray(parsed)) {
    return parsed;
  }
  if (!parsed || typeof parsed !== "object") {
    return null;
  }

  const sequence = parsed.glossSequence;
  if (Array.isArray(sequence)) {
    return sequence;
  }
  if (typeof sequence === "string" && sequence.trim()) {
    return sequence.trim().split(/\s+/);
  }

  return null;
}

function normalizeGlossSequence(tokens) {
  return tokens
    .map((token) =>
      String(token)
        .trim()
        .toUpperCase()
        .replace(/[^\w-?]/g, ""),
    )
    .filter((token) => token && !JSON_ARTIFACT_TOKENS.has(token));
}

function parseSignText(content) {
  const text = String(content).trim();
  try {
    const parsed = JSON.parse(text);
    if (parsed && typeof parsed.text === "string") {
      return parsed.text.trim();
    }
  } catch (_) {
    // fall through
  }

  const objectMatch = text.match(/\{[\s\S]*"text"[\s\S]*\}/);
  if (objectMatch) {
    try {
      const parsed = JSON.parse(objectMatch[0]);
      if (parsed && typeof parsed.text === "string") {
        return parsed.text.trim();
      }
    } catch (_) {
      // fall through
    }
  }

  throw new Error(`Unable to parse sign response: ${text.slice(0, 120)}`);
}

function bytesToBase64(bytes) {
  const chunkSize = 0x8000;
  const uint8 = new Uint8Array(bytes);
  let binary = "";
  for (let i = 0; i < uint8.length; i += chunkSize) {
    const chunk = uint8.subarray(i, i + chunkSize);
    binary += String.fromCharCode.apply(null, chunk);
  }
  return btoa(binary);
}

function signJson(obj, status = 200) {
  if (status === 204) {
    return new Response(null, {
      status,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, X-SignBridge-Key",
      },
    });
  }

  return new Response(JSON.stringify(obj), {
    status,
    headers: {
      ...JSON_HEADERS,
      "Access-Control-Allow-Origin": "*",
    },
  });
}
