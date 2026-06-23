/**
 * Shared sign video → gloss → spoken text handler for Cloudflare Workers.
 *
 * Primary: Adesso video → spoken text, then Groq text → gloss.
 * Fallback: Gemini quality chain (see gemini_model_chain.js).
 */

import { geminiQualityChain } from "./gemini_model_chain.js";
import {
  JSON_HEADERS as GLOSS_JSON_HEADERS,
  adessoConfigured,
  adessoModel,
  captionToGlossGroq,
  groqConfigured,
} from "./gloss_providers.js";

const JSON_HEADERS = GLOSS_JSON_HEADERS;
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
  const conversationContext = (form.get("conversationContext") || "")
    .toString()
    .trim();

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
      conversationContext,
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
  return geminiQualityChain(env, { primaryVar: "SIGN_GEMINI_MODEL" });
}

function geminiTextModels(env) {
  return geminiQualityChain(env, { primaryVar: "GEMINI_MODEL" });
}

function isRetryableGeminiStatus(status) {
  return status === 429 || status === 500 || status === 503 || status === 504;
}

function isModelUnavailableStatus(status) {
  return status === 404 || status === 400;
}

function shouldFailOverSignModel(err) {
  const status = err.status || 0;
  if (isModelUnavailableStatus(status) || status === 429) {
    return true;
  }
  const message = String(err).toLowerCase();
  return (
    message.includes("no signs detected") ||
    message.includes("empty sign gloss") ||
    message.includes("empty sign recognition") ||
    message.includes("unable to parse")
  );
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

function signGrammarHint(signLanguage, spoken) {
  const sign = signLanguage.trim().toUpperCase();
  if (sign === "ISL") {
    return (
      `ISL gloss follows sign order (often SOV), not ${spoken} word order. ` +
      `Use standard ISL gloss tokens (e.g. ME, NAME, WATER, WANT, DEAF). `
    );
  }
  return (
    `ASL gloss follows sign order (topic-comment / time-first), not ${spoken} word order. ` +
    `Use standard ASL gloss tokens (e.g. ME, NAME, WATER, WANT, DEAF). `
  );
}

function signRecognitionSystemInstruction(
  signLanguage,
  languageCode,
  durationMs,
  conversationContext,
) {
  const sign = signLanguage.trim().toUpperCase();
  const spoken = spokenLanguageName(languageCode);
  const expected = expectedSignCount(durationMs);
  const seconds = signDurationSeconds(durationMs);
  const durationHint =
    seconds > 0
      ? `The clip is about ${seconds} second(s). Expect roughly ${expected ?? "several"} distinct signs. `
      : "";

  let contextHint = "";
  if (conversationContext) {
    contextHint =
      `Conversation context — the hearing person just said: "${conversationContext}". ` +
      `The signer is replying in ${sign}. Use this to disambiguate similar signs. `;
  }

  return (
    `You are an expert ${sign} interpreter analyzing a front-camera selfie signing clip. ` +
    contextHint +
    signGrammarHint(signLanguage, spoken) +
    durationHint +
    `Return JSON only: {"glossSequence":["TOKEN","..."],"text":"..."}. ` +
    `glossSequence: ONE UPPERCASE token per distinct sign, chronological order. ` +
    `Include EVERY sign from start to finish—do not stop after the first sign. ` +
    `text: natural ${spoken} sentence(s) for what the signer meant, correct ${spoken} grammar. ` +
    `Do not describe hands, camera, clothing, or background. ` +
    `If nothing was clearly signed, return {"glossSequence":[],"text":""}.`
  );
}

function signRecognitionUserPrompt(signLanguage, languageCode, durationMs) {
  const spoken = spokenLanguageName(languageCode);
  const expected = expectedSignCount(durationMs);
  const seconds = signDurationSeconds(durationMs);
  const countHint =
    expected != null && seconds >= 2
      ? ` Expect about ${expected} gloss tokens.`
      : "";
  return (
    `Watch the entire ${signLanguage.trim()} signing video. ` +
    `List each sign as a gloss token in order, then write the ${spoken} translation.${countHint}`
  );
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
    `Use ALL gloss tokens in order—do not drop signs. ` +
    `Infer the signer's intended meaning, not a literal word-for-word gloss reading. ` +
    `Write fluent ${spoken} sentences with correct grammar.`
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

const SIGN_RECOGNITION_RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    glossSequence: {
      type: "ARRAY",
      items: { type: "STRING" },
      description:
        "One UPPERCASE gloss token per distinct sign, chronological order.",
    },
    text: {
      type: "STRING",
      description:
        "Natural spoken-language translation of the signed message.",
    },
  },
  required: ["glossSequence", "text"],
  propertyOrdering: ["glossSequence", "text"],
};

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

const MIN_RECOGNITION_SCORE = 15;

export function scoreRecognitionResult(
  glossSequence,
  text,
  durationMs,
  conversationContext = "",
) {
  const glossCount = Array.isArray(glossSequence) ? glossSequence.length : 0;
  const spoken = String(text || "").trim();
  if (!glossCount || !spoken) {
    return 0;
  }

  let score = glossCount * 10;
  const expected = expectedSignCount(durationMs);
  if (expected != null && durationMs >= 2500) {
    if (glossCount >= expected) {
      score += 20;
    } else if (glossCount < Math.max(1, Math.floor(expected * 0.5))) {
      score -= 25;
    }
  }

  if (spoken.length >= 12) {
    score += 10;
  }

  const context = String(conversationContext || "").trim().toLowerCase();
  if (context) {
    const keywords = context
      .split(/[^a-z0-9\u0900-\u0dff\u0b80-\u0bff\u0d00-\u0d7f]+/i)
      .filter((word) => word.length > 3);
    const spokenLower = spoken.toLowerCase();
    for (const word of keywords) {
      if (spokenLower.includes(word)) {
        score += 6;
      }
    }
  }

  return score;
}

function adessoVideoModel(env) {
  return (env.ADESSO_VIDEO_MODEL || env.ADESSO_MODEL || "qwen-3.6-35b-sovereign").trim();
}

function signVideoToTextSystemInstruction(signLanguage, languageCode, conversationContext) {
  const sign = signLanguage.trim().toUpperCase();
  const spoken = spokenLanguageName(languageCode);
  let contextHint = "";
  if (conversationContext) {
    contextHint =
      `The hearing person just said: "${conversationContext}". ` +
      `The signer is replying in ${sign}. Use this for context. `;
  }
  return (
    `You watch ${sign} sign-language video and write what the signer meant in ${spoken}. ` +
    contextHint +
    `Return JSON only: {"text":"..."}. ` +
    `Write natural ${spoken} sentence(s). Do not describe hands, camera, or background. ` +
    `If nothing was signed, return {"text":""}.`
  );
}

function signVideoToTextUserPrompt(signLanguage, languageCode, durationMs) {
  const spoken = spokenLanguageName(languageCode);
  const seconds = signDurationSeconds(durationMs);
  const hint = seconds > 0 ? ` Clip is about ${seconds} seconds.` : "";
  return (
    `Translate this ${signLanguage.trim()} signing video into ${spoken}.${hint}`
  );
}

function adessoVideoUserContent(bytes, mimeType, signLanguage, languageCode, durationMs) {
  const dataUrl = `data:${mimeType};base64,${bytesToBase64(bytes)}`;
  const text = signVideoToTextUserPrompt(signLanguage, languageCode, durationMs);
  return [
    { type: "text", text },
    { type: "image_url", image_url: { url: dataUrl } },
  ];
}

async function videoToTextAdesso(
  bytes,
  mimeType,
  signLanguage,
  languageCode,
  durationMs,
  conversationContext,
  env,
) {
  const model = adessoVideoModel(env);
  const res = await fetch(`${env.ADESSO_API_URL}/chat/completions`, {
    method: "POST",
    headers: {
      ...JSON_HEADERS,
      Authorization: `Bearer ${env.ADESSO_KEY}`,
    },
    body: JSON.stringify({
      model,
      temperature: 0.1,
      max_tokens: 512,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content: signVideoToTextSystemInstruction(
            signLanguage,
            languageCode,
            conversationContext,
          ),
        },
        {
          role: "user",
          content: adessoVideoUserContent(
            bytes,
            mimeType,
            signLanguage,
            languageCode,
            durationMs,
          ),
        },
      ],
    }),
  });

  if (!res.ok) {
    const error = new Error(`Adesso ${res.status}: ${await res.text()}`);
    error.status = res.status;
    throw error;
  }

  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content;
  if (!content) {
    throw new Error("Adesso returned empty sign video response");
  }

  const text = parseSignVideoText(content);
  if (!text) {
    throw new Error("Adesso returned empty sign text");
  }

  return { text, modelUsed: `adesso:${model}` };
}

function parseSignVideoText(content) {
  const raw = String(content).trim();
  try {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed.text === "string") {
      return parsed.text.trim();
    }
  } catch (_) {
    // fall through
  }

  const objectMatch = raw.match(/\{[\s\S]*"text"[\s\S]*\}/);
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

  if (raw && !raw.startsWith("{")) {
    return raw;
  }

  throw new Error(`Unable to parse Adesso video response: ${raw.slice(0, 120)}`);
}

async function videoToSpokenTextAdessoGroq(
  bytes,
  mimeType,
  languageCode,
  signLanguage,
  durationMs,
  conversationContext,
  env,
) {
  if (!adessoConfigured(env)) {
    throw new Error("ADESSO_KEY and ADESSO_API_URL not configured");
  }
  if (!groqConfigured(env)) {
    throw new Error("GROQ_KEY not configured for gloss");
  }

  const context = String(conversationContext || "").trim();
  const { text, modelUsed: videoModel } = await videoToTextAdesso(
    bytes,
    mimeType,
    signLanguage,
    languageCode,
    durationMs,
    context,
    env,
  );

  const { glossSequence, modelUsed: glossModel } = await captionToGlossGroq(
    text,
    signLanguage,
    env,
  );

  return {
    text,
    glossSequence,
    modelUsed: `${videoModel}+${glossModel}`,
  };
}

async function videoToSpokenText(
  bytes,
  mimeType,
  languageCode,
  signLanguage,
  durationMs,
  conversationContext,
  env,
) {
  const errors = [];

  if (adessoConfigured(env) && groqConfigured(env)) {
    try {
      return await videoToSpokenTextAdessoGroq(
        bytes,
        mimeType,
        languageCode,
        signLanguage,
        durationMs,
        conversationContext,
        env,
      );
    } catch (err) {
      errors.push(err);
    }
  }

  const geminiResult = await videoToSpokenTextGemini(
    bytes,
    mimeType,
    languageCode,
    signLanguage,
    durationMs,
    conversationContext,
    env,
    errors,
  );
  if (geminiResult) {
    return geminiResult;
  }

  const detail = errors.map((err) => String(err).slice(0, 80)).join(" | ");
  throw new Error(detail || "No sign recognition provider configured");
}

async function videoToSpokenTextGemini(
  bytes,
  mimeType,
  languageCode,
  signLanguage,
  durationMs,
  conversationContext,
  env,
  errors = [],
) {
  const apiKey = geminiApiKey(env);
  if (!apiKey) {
    return null;
  }

  const context = String(conversationContext || "").trim();
  const models = geminiModels(env);
  let best = null;
  let bestScore = 0;

  for (const model of models) {
    try {
      const result = await requestGeminiSignRecognition(
        model,
        bytes,
        mimeType,
        signLanguage,
        languageCode,
        durationMs,
        context,
        apiKey,
      );
      const score = scoreRecognitionResult(
        result.glossSequence,
        result.text,
        durationMs,
        context,
      );
      if (score > bestScore) {
        bestScore = score;
        best = { ...result, glossModel: model };
      }
      if (bestScore >= MIN_RECOGNITION_SCORE) {
        break;
      }
    } catch (err) {
      errors.push(err);
      if (!shouldFailOverSignModel(err)) {
        break;
      }
    }
  }

  if (best && best.glossSequence.length && best.text.trim()) {
    return {
      text: best.text.trim(),
      glossSequence: best.glossSequence,
      modelUsed: `gemini:${best.glossModel}`,
    };
  }

  // Fallback: separate gloss then text passes (older two-stage path).
  const { glossSequence, glossModel } = await videoToGlossSequence(
    bytes,
    mimeType,
    signLanguage,
    durationMs,
    apiKey,
    env,
  );

  if (!glossSequence.length) {
    return null;
  }

  const { text, textModel } = await glossSequenceToSpokenText(
    glossSequence,
    languageCode,
    signLanguage,
    apiKey,
    env,
  );

  if (!text.trim()) {
    return null;
  }

  return {
    text: text.trim(),
    glossSequence,
    modelUsed: `gemini:${glossModel}+${textModel}`,
  };
}

async function requestGeminiSignRecognition(
  model,
  bytes,
  mimeType,
  signLanguage,
  languageCode,
  durationMs,
  conversationContext,
  apiKey,
) {
  let lastError = null;

  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const result = await callGeminiSignRecognition(
        model,
        bytes,
        mimeType,
        signLanguage,
        languageCode,
        durationMs,
        conversationContext,
        apiKey,
      );
      if (!result.glossSequence.length || !result.text.trim()) {
        throw new Error("Empty sign recognition result");
      }
      return result;
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

  throw lastError || new Error("Gemini sign recognition request failed");
}

function signGenerationConfig(model, schema) {
  const config = {
    temperature: 0.0,
    topP: 0.1,
    topK: 1,
    maxOutputTokens: 512,
    responseMimeType: "application/json",
    responseSchema: schema,
  };
  if (model.includes("gemini-3")) {
    config.thinkingConfig = { thinkingLevel: "MEDIUM" };
  }
  return config;
}

async function callGeminiSignRecognition(
  model,
  bytes,
  mimeType,
  signLanguage,
  languageCode,
  durationMs,
  conversationContext,
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
            text: signRecognitionSystemInstruction(
              signLanguage,
              languageCode,
              durationMs,
              conversationContext,
            ),
          },
        ],
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
            {
              text: signRecognitionUserPrompt(
                signLanguage,
                languageCode,
                durationMs,
              ),
            },
          ],
        },
      ],
      generationConfig: signGenerationConfig(
        model,
        SIGN_RECOGNITION_RESPONSE_SCHEMA,
      ),
    }),
  });

  if (!res.ok) {
    const detail = await res.text();
    const error = new Error(`Gemini ${res.status}: ${detail}`);
    error.status = res.status;
    throw error;
  }

  const data = await res.json();
  const content = extractGeminiText(data);
  if (!content) {
    throw geminiEmptyResponseError(data, "sign recognition");
  }

  return parseSignRecognition(content);
}

function extractGeminiText(data) {
  return data?.candidates?.[0]?.content?.parts?.[0]?.text || "";
}

function geminiEmptyResponseError(data, stage) {
  const finishReason = data?.candidates?.[0]?.finishReason || "unknown";
  const blockReason = data?.promptFeedback?.blockReason || "";
  const suffix = blockReason
    ? ` finish=${finishReason} block=${blockReason}`
    : ` finish=${finishReason}`;
  return new Error(`Gemini returned empty ${stage} response${suffix}`);
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
      generationConfig: signGenerationConfig(model, SIGN_GLOSS_RESPONSE_SCHEMA),
    }),
  });

  if (!res.ok) {
    const detail = await res.text();
    const error = new Error(`Gemini ${res.status}: ${detail}`);
    error.status = res.status;
    throw error;
  }

  const data = await res.json();
  const content = extractGeminiText(data);
  if (!content) {
    throw geminiEmptyResponseError(data, "sign gloss");
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
      generationConfig: signGenerationConfig(model, SIGN_TEXT_RESPONSE_SCHEMA),
    }),
  });

  if (!res.ok) {
    const detail = await res.text();
    const error = new Error(`Gemini ${res.status}: ${detail}`);
    error.status = res.status;
    throw error;
  }

  const data = await res.json();
  const content = extractGeminiText(data);
  if (!content) {
    throw geminiEmptyResponseError(data, "gloss-to-text");
  }

  return parseSignText(content);
}

function parseSignRecognition(content) {
  const text = String(content).trim();
  let parsed = null;

  try {
    parsed = JSON.parse(text);
  } catch (_) {
    const objectMatch = text.match(/\{[\s\S]*"glossSequence"[\s\S]*\}/);
    if (objectMatch) {
      try {
        parsed = JSON.parse(objectMatch[0]);
      } catch (_) {
        // fall through
      }
    }
  }

  if (!parsed || typeof parsed !== "object") {
    throw new Error(`Unable to parse sign recognition response: ${text.slice(0, 120)}`);
  }

  const glossSequence = normalizeGlossSequence(
    glossTokensFromParsed(parsed) || [],
  );
  const spoken =
    typeof parsed.text === "string" ? parsed.text.trim() : "";

  return { glossSequence, text: spoken };
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
