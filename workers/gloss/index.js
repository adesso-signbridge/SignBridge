/**
 * SignBridge gloss Worker — POST { caption, signLanguage } → glossSequence[].
 * POST /sign (multipart video) → spoken text via sign_recognition.js.
 * Gloss (POST /): Groq → Adesso → Gemini fallback.
 * Sign video (POST /sign): Adesso video→text + Groq gloss → Gemini fallback.
 * Secrets: GROQ_KEY, GEMINI_KEY, ADESSO_KEY, ADESSO_API_URL, WORKER_SHARED_KEY.
 */

import { geminiQualityChain } from "../gemini_model_chain.js";
import {
  JSON_HEADERS,
  captionToGloss as captionToGlossGroqFirst,
  groqConfigured,
  adessoConfigured,
  glossSystemInstruction,
  glossUserMessage,
  parseGloss,
} from "../gloss_providers.js";
import { handleSignRecognitionRequest } from "../sign_recognition.js";

export default {
  async fetch(request, env) {
    const pathname = new URL(request.url).pathname;
    if (pathname.endsWith("/sign")) {
      return handleSignRecognitionRequest(request, env);
    }

    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, X-SignBridge-Key",
        },
      });
    }

    if (request.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    if (env.WORKER_SHARED_KEY) {
      const provided = request.headers.get("X-SignBridge-Key");
      if (provided !== env.WORKER_SHARED_KEY) {
        return json({ error: "Unauthorized" }, 401);
      }
    }

    let body;
    try {
      body = await request.json();
    } catch (_) {
      return json({ error: "Invalid JSON body" }, 400);
    }

    const caption = (body.caption || "").trim();
    const signLanguage = (body.signLanguage || "ASL").trim();
    const jobId = (body.jobId || crypto.randomUUID()).trim();

    if (!caption) {
      return json({ error: "Missing caption" }, 400);
    }

    let glossSequence;
    let modelUsed;
    try {
      ({ glossSequence, modelUsed } = await captionToGloss(caption, signLanguage, env));
    } catch (err) {
      return json(
        { error: "Gloss request failed", detail: String(err).slice(0, 300), jobId },
        502,
      );
    }

    return json({ ok: true, jobId, glossSequence, modelUsed });
  },
};

function geminiApiKey(env) {
  return env.GEMINI_KEY || env.GEMINI_API_KEY || "";
}

async function captionToGloss(caption, signLanguage, env) {
  const errors = [];

  if (groqConfigured(env) || adessoConfigured(env)) {
    try {
      return await captionToGlossGroqFirst(caption, signLanguage, env);
    } catch (err) {
      errors.push(err);
    }
  }

  if (geminiApiKey(env)) {
    const models = geminiModels(env);
    for (let index = 0; index < models.length; index++) {
      const model = models[index];
      const timeoutMs = index === 0 ? geminiPrimaryTimeoutMs(env) : 0;
      try {
        return await captionToGlossGemini(
          caption,
          signLanguage,
          env,
          model,
          timeoutMs,
        );
      } catch (err) {
        errors.push(err);
      }
    }
  }

  const detail = errors.map((err) => String(err).slice(0, 80)).join(" | ");
  throw new Error(detail || "No gloss provider configured");
}

function geminiPrimaryTimeoutMs(env) {
  const parsed = Number(env.GEMINI_PRIMARY_TIMEOUT_MS);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 6000;
}

function geminiModels(env) {
  return geminiQualityChain(env, { primaryVar: "GEMINI_MODEL" });
}

function isRetryableGeminiStatus(status) {
  return status === 429 || status === 500 || status === 503 || status === 504;
}

function isModelUnavailableStatus(status) {
  return status === 404 || status === 400;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function captionToGlossGemini(
  caption,
  signLanguage,
  env,
  model,
  timeoutMs = 0,
) {
  const apiKey = geminiApiKey(env);
  if (!apiKey) {
    throw new Error("GEMINI_KEY not configured");
  }

  const resolvedModel = (model || env.GEMINI_MODEL || "gemini-3.5-flash").trim();
  let lastError = null;

  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const glossSequence = await requestGeminiGloss(
        resolvedModel,
        caption,
        signLanguage,
        apiKey,
        timeoutMs,
      );
      if (isInvalidGlossResponse(glossSequence)) {
        throw new Error("Gemini returned invalid gloss tokens");
      }
      return { glossSequence, modelUsed: resolvedModel };
    } catch (err) {
      lastError = err;
      if (isTimeoutError(err)) {
        break;
      }
      const status = err.status || 0;
      if (isModelUnavailableStatus(status)) {
        break;
      }
      if (!isRetryableGeminiStatus(status) || attempt === 2) {
        break;
      }
      await sleep(400 * (attempt + 1));
    }
  }

  throw lastError || new Error("Gemini request failed");
}

const GLOSS_RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    glossSequence: {
      type: "ARRAY",
      items: { type: "STRING" },
      description:
        "ASL/ISL gloss tokens in sign-language word order. All strings UPPERCASE. No articles or filler.",
      minItems: 1,
    },
  },
  required: ["glossSequence"],
  propertyOrdering: ["glossSequence"],
};

function isTimeoutError(err) {
  if (!err) {
    return false;
  }
  if (err.name === "AbortError" || err.name === "TimeoutError") {
    return true;
  }
  return String(err).toLowerCase().includes("timeout");
}

async function requestGeminiGloss(
  model,
  caption,
  signLanguage,
  apiKey,
  timeoutMs = 0,
) {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}` +
    `:generateContent?key=${encodeURIComponent(apiKey)}`;

  const controller = timeoutMs > 0 ? new AbortController() : null;
  const timer =
    controller &&
    setTimeout(() => controller.abort(new Error(`Gemini timeout after ${timeoutMs}ms`)), timeoutMs);

  let res;
  try {
    res = await fetch(url, {
      method: "POST",
      headers: JSON_HEADERS,
      signal: controller?.signal,
      body: JSON.stringify({
        systemInstruction: {
          parts: [{ text: glossSystemInstruction(signLanguage) }],
        },
        contents: [
          {
            role: "user",
            parts: [{ text: glossUserMessage(caption, signLanguage) }],
          },
        ],
        generationConfig: {
          temperature: 0.0,
          topP: 0.1,
          topK: 1,
          maxOutputTokens: 96,
          responseMimeType: "application/json",
          responseSchema: GLOSS_RESPONSE_SCHEMA,
        },
      }),
    });
  } finally {
    if (timer) {
      clearTimeout(timer);
    }
  }

  if (!res.ok) {
    const detail = await res.text();
    const error = new Error(`Gemini ${res.status}: ${detail}`);
    error.status = res.status;
    throw error;
  }

  const data = await res.json();
  const content = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!content) {
    throw new Error("Gemini returned empty gloss response");
  }
  return parseGloss(content);
}

const JSON_ARTIFACT_TOKENS = new Set(["GLOSSSEQUENCE", "GLOSSEQUENCE"]);

function isInvalidGlossResponse(tokens) {
  return !tokens || tokens.length === 0 || tokens.every((token) => JSON_ARTIFACT_TOKENS.has(token));
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: {
      ...JSON_HEADERS,
      "Access-Control-Allow-Origin": "*",
    },
  });
}
