/**
 * Shared sign video → spoken text handler for Cloudflare Workers.
 *
 * One Gemini call: watch the clip and return natural spoken-language text.
 * Primary: EU-hosted gemini-3.5-flash via Adesso AI Hub OpenAI-compatible API
 *   POST {ADESSO_API_URL}/chat/completions  (same as hub OpenAI SDK sample).
 * Fallback: direct Google Gemini generateContent when GEMINI_KEY is set.
 */

import { geminiSignVideoOnlyChain } from "./gemini_model_chain.js";

const JSON_HEADERS = { "Content-Type": "application/json" };
const MAX_VIDEO_BYTES = 10 * 1024 * 1024;

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
    return signJson({ error: "Video too large (max 10 MB)" }, 413);
  }

  const mimeType = resolveVideoMimeType(video);

  let text;
  let modelUsed;
  try {
    ({ text, modelUsed } = await videoToSpokenText(
      bytes,
      mimeType,
      languageCode,
      signLanguage,
      conversationContext,
      durationMs,
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
    glossSequence: [],
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

function adessoConfigured(env) {
  return Boolean(env.ADESSO_KEY && env.ADESSO_API_URL);
}

function signGeminiModel(env) {
  return (env.SIGN_GEMINI_MODEL || "gemini-3.5-flash").trim();
}

/** Hub root without trailing /v1 — e.g. https://adesso-ai-hub.3asabc.de */
function adessoApiRoot(env) {
  return (env.ADESSO_API_URL || "").trim().replace(/\/v1\/?$/, "").replace(/\/+$/, "");
}

function adessoChatCompletionsUrl(env) {
  const base = (env.ADESSO_API_URL || "").trim().replace(/\/+$/, "");
  return `${base}/chat/completions`;
}

function adessoGeminiGenerateContentUrls(env, model) {
  const root = adessoApiRoot(env);
  return [
    `${root}/v1beta/models/${model}:generateContent`,
    `${root}/v1/models/${model}:generateContent`,
  ];
}

function geminiModels(env) {
  return geminiSignVideoOnlyChain(env);
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

function outputScriptHint(languageCode) {
  switch (languageCode.trim().toUpperCase()) {
    case "HI":
      return "Write Hindi in Devanagari script (e.g. आप कैसे हैं?), never Latin romanization.";
    case "TA":
      return "Write Tamil in Tamil script (e.g. நீங்கள் எப்படி இருக்கிறீர்கள்?), never Latin romanization.";
    case "ML":
      return "Write Malayalam in Malayalam script (e.g. സുഖമാണോ?), never Latin romanization.";
    default:
      return "Write natural English with normal punctuation.";
  }
}

function clipDurationHint(durationMs) {
  const seconds = Number.isFinite(durationMs) ? durationMs / 1000 : 0;
  if (seconds <= 0) {
    return (
      "The clip is very short (a few seconds). Expect at most one short phrase " +
      "or 1–3 signs — do not invent extra words."
    );
  }
  if (seconds < 3) {
    return (
      `The clip is about ${seconds.toFixed(1)}s — usually one word or a brief reply ` +
      "(greeting, yes/no, thanks, or a single question)."
    );
  }
  if (seconds <= 5) {
    return (
      `The clip is about ${seconds.toFixed(1)}s — usually a short phrase of 2–5 signs. ` +
      "Translate only what was clearly signed."
    );
  }
  return (
    `The clip is about ${seconds.toFixed(1)}s. Translate the signed message faithfully ` +
    "without adding unstated detail."
  );
}

function signSystemInstruction(signLanguage, languageCode, durationMs) {
  const sign = signLanguage.trim().toUpperCase();
  const spoken = spokenLanguageName(languageCode);
  const scriptRule = outputScriptHint(languageCode);
  const durationRule = clipDurationHint(durationMs);

  const shared = [
    `You are an expert ${sign} interpreter decoding a mobile-camera signing clip.`,
    `Return JSON only: {"text":"..."}.`,
    `The "text" value must be natural ${spoken} that a hearing person would understand.`,
    scriptRule,
    durationRule,
    "Decode sign meaning, not a scene description.",
    "Never mention hands, fingers, face, camera, background, or the video.",
    "Never output gloss tokens, finger-spelling, or mixed-language romanization.",
    "Do not wrap the answer in quotes or add labels like Translation:.",
    'If nothing was clearly signed, return {"text":""}.',
  ];

  if (sign.includes("ISL")) {
    shared.push(
      "The signer uses Indian Sign Language (ISL).",
      "ISL uses spatial grammar and facial expressions (raised brows often mark questions).",
      `Map signs to idiomatic ${spoken}, not word-for-word English order.`,
      "Prefer everyday conversational phrasing over literal gloss order.",
      "Examples of intended output (not gloss):",
      "YOU HOW → Hindi: आप कैसे हैं? | Tamil: நீங்கள் எப்படி இருக்கிறீர்கள்?",
      "THANK YOU → Hindi: धन्यवाद | Tamil: நன்றி",
      "YOUR NAME WHAT → Hindi: आपका नाम क्या है? | Tamil: உங்கள் பெயர் என்ன?",
      "YES / NO → use the natural ${spoken} word for yes or no.",
    );
  } else {
    shared.push(
      "The signer uses American Sign Language (ASL).",
      "ASL topic-comment and WH-question structure may differ from English word order.",
      "Output fluent English that preserves question vs statement intent.",
      "Examples: HOW YOU → How are you? | NAME YOU WHAT → What is your name? | THANK YOU → Thank you.",
    );
  }

  return shared.join(" ");
}

function signUserPrompt(
  signLanguage,
  languageCode,
  conversationContext,
  durationMs,
) {
  const sign = signLanguage.trim().toUpperCase();
  const spoken = spokenLanguageName(languageCode);
  const durationRule = clipDurationHint(durationMs);

  let prompt =
    `Watch this ${sign} signing clip and write the ${spoken} sentence the signer meant. ` +
    `${durationRule}`;

  const context = (conversationContext || "").trim();
  if (context) {
    prompt +=
      ` Context: a hearing person recently said "${context}". ` +
      `The deaf signer is replying in ${sign}. ` +
      `Your ${spoken} output should be their reply (or standalone message if not a direct answer).`;
  } else {
    prompt +=
      " There is no prior conversation — translate only what was signed in the clip.";
  }

  return prompt;
}

const SIGN_RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    text: {
      type: "STRING",
      description: "Natural spoken-language translation of the signed message.",
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
  conversationContext,
  durationMs,
  env,
) {
  const model = signGeminiModel(env);
  if (!model) {
    throw new Error("SIGN_GEMINI_MODEL not configured");
  }

  const errors = [];

  if (adessoConfigured(env)) {
    try {
      return await requestAdessoSignText(
        model,
        bytes,
        mimeType,
        languageCode,
        signLanguage,
        conversationContext,
        durationMs,
        env,
      );
    } catch (err) {
      errors.push(err);
    }
  }

  const apiKey = geminiApiKey(env);
  if (apiKey) {
    for (const fallbackModel of geminiModels(env)) {
      try {
        return await requestGeminiSignText(
          fallbackModel,
          bytes,
          mimeType,
          languageCode,
          signLanguage,
          conversationContext,
          durationMs,
          apiKey,
        );
      } catch (err) {
        errors.push(err);
        if (isModelUnavailableStatus(err.status || 0)) {
          continue;
        }
      }
    }
  }

  if (!adessoConfigured(env) && !apiKey) {
    throw new Error("ADESSO_KEY/ADESSO_API_URL or GEMINI_KEY not configured");
  }

  const detail = errors.map((err) => String(err).slice(0, 80)).join(" | ");
  throw new Error(detail || "Sign recognition failed");
}

async function requestAdessoSignText(
  model,
  bytes,
  mimeType,
  languageCode,
  signLanguage,
  conversationContext,
  durationMs,
  env,
) {
  let lastError = null;

  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const text = await callAdessoSignText(
        model,
        bytes,
        mimeType,
        languageCode,
        signLanguage,
        conversationContext,
        durationMs,
        env,
      );
      if (!text.trim()) {
        throw new Error("No signs detected in video");
      }
      return { text: text.trim(), modelUsed: `adesso:${model}` };
    } catch (err) {
      lastError = err;
      const status = err.status || 0;
      if (isModelUnavailableStatus(status)) {
        break;
      }
      if (!isRetryableGeminiStatus(status) || attempt === 2) {
        break;
      }
      await sleep(500 * (attempt + 1));
    }
  }

  throw lastError || new Error("Adesso sign request failed");
}

function buildGeminiSignRequestBody(
  bytes,
  mimeType,
  languageCode,
  signLanguage,
  conversationContext,
  durationMs,
) {
  return {
    systemInstruction: {
      parts: [
        {
          text: signSystemInstruction(signLanguage, languageCode, durationMs),
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
            text: signUserPrompt(
              signLanguage,
              languageCode,
              conversationContext,
              durationMs,
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
      responseSchema: SIGN_RESPONSE_SCHEMA,
    },
  };
}

async function callAdessoSignText(
  model,
  bytes,
  mimeType,
  languageCode,
  signLanguage,
  conversationContext,
  durationMs,
  env,
) {
  const authHeaders = {
    ...JSON_HEADERS,
    Authorization: `Bearer ${env.ADESSO_KEY}`,
  };
  const base64 = bytesToBase64(bytes);
  const dataUrl = `data:${mimeType};base64,${base64}`;
  const system = signSystemInstruction(signLanguage, languageCode, durationMs);
  const userText = signUserPrompt(
    signLanguage,
    languageCode,
    conversationContext,
    durationMs,
  );
  const chatUrl = adessoChatCompletionsUrl(env);

  const chatPayloads = [
    {
      model,
      temperature: 0,
      max_tokens: 512,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: system },
        {
          role: "user",
          content: [
            { type: "text", text: userText },
            { type: "video_url", video_url: { url: dataUrl } },
          ],
        },
      ],
    },
    {
      model,
      temperature: 0,
      max_tokens: 512,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: system },
        {
          role: "user",
          content: [
            {
              type: "file",
              file: {
                filename: "sign.mp4",
                file_data: dataUrl,
              },
            },
            { type: "text", text: userText },
          ],
        },
      ],
    },
  ];

  const errors = [];
  for (const body of chatPayloads) {
    try {
      return await parseAdessoChatSignResponse(
        await fetch(chatUrl, {
          method: "POST",
          headers: authHeaders,
          body: JSON.stringify(body),
        }),
      );
    } catch (err) {
      errors.push(err);
    }
  }

  const nativeBody = buildGeminiSignRequestBody(
    bytes,
    mimeType,
    languageCode,
    signLanguage,
    conversationContext,
    durationMs,
  );
  for (const url of adessoGeminiGenerateContentUrls(env, model)) {
    try {
      return await parseGeminiSignResponse(
        await fetch(url, {
          method: "POST",
          headers: authHeaders,
          body: JSON.stringify(nativeBody),
        }),
        "Adesso",
      );
    } catch (err) {
      errors.push(err);
      if (!isModelUnavailableStatus(err.status || 0)) {
        throw err;
      }
    }
  }

  const detail = errors.map((err) => String(err).slice(0, 80)).join(" | ");
  throw new Error(detail || "Adesso sign recognition failed");
}

async function parseAdessoChatSignResponse(res) {
  if (!res.ok) {
    const detail = await res.text();
    const error = new Error(`Adesso ${res.status}: ${detail}`);
    error.status = res.status;
    throw error;
  }

  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content;
  if (!content) {
    throw new Error("Adesso returned empty sign response");
  }
  return parseSignText(content);
}

async function parseGeminiSignResponse(res, providerLabel) {
  if (!res.ok) {
    const detail = await res.text();
    const error = new Error(`${providerLabel} ${res.status}: ${detail}`);
    error.status = res.status;
    throw error;
  }

  const data = await res.json();
  const content = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!content) {
    throw new Error(`${providerLabel} returned empty sign response`);
  }
  return parseSignText(content);
}

async function requestGeminiSignText(
  model,
  bytes,
  mimeType,
  languageCode,
  signLanguage,
  conversationContext,
  durationMs,
  apiKey,
) {
  let lastError = null;

  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const text = await callGeminiSignText(
        model,
        bytes,
        mimeType,
        languageCode,
        signLanguage,
        conversationContext,
        durationMs,
        apiKey,
      );
      if (!text.trim()) {
        throw new Error("No signs detected in video");
      }
      return { text: text.trim(), modelUsed: model };
    } catch (err) {
      lastError = err;
      const status = err.status || 0;
      if (isModelUnavailableStatus(status)) {
        break;
      }
      if (!isRetryableGeminiStatus(status) || attempt === 2) {
        break;
      }
      await sleep(500 * (attempt + 1));
    }
  }

  throw lastError || new Error("Gemini sign request failed");
}

async function callGeminiSignText(
  model,
  bytes,
  mimeType,
  languageCode,
  signLanguage,
  conversationContext,
  durationMs,
  apiKey,
) {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}` +
    `:generateContent?key=${encodeURIComponent(apiKey)}`;

  return parseGeminiSignResponse(
    await fetch(url, {
      method: "POST",
      headers: JSON_HEADERS,
      body: JSON.stringify(
        buildGeminiSignRequestBody(
          bytes,
          mimeType,
          languageCode,
          signLanguage,
          conversationContext,
          durationMs,
        ),
      ),
    }),
    "Gemini",
  );
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

  const fenceMatch = text.match(/```(?:json)?\s*(\{[\s\S]*?\})\s*```/i);
  if (fenceMatch) {
    try {
      const parsed = JSON.parse(fenceMatch[1]);
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
