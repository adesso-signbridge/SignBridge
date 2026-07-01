/**
 * SignBridge gloss Worker — POST { caption, signLanguage } → glossSequence[].
 * POST /sign (multipart video) → spoken text via Adesso EU gemini-3.5-flash.
 * Gloss (POST /): Adesso Qwen 3.5 122B → Groq (ASL only) → Gemini fallback.
 * Sign video (POST /sign): Adesso gemini-3.5-flash → direct Gemini fallback.
 * Secrets: GROQ_KEY, GEMINI_KEY, ADESSO_KEY, ADESSO_API_URL, WORKER_SHARED_KEY.
 */

import { geminiQualityChain } from "../gemini_model_chain.js";
import { handleSignRecognitionRequest } from "../sign_recognition.js";

const JSON_HEADERS = { "Content-Type": "application/json" };

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
    const glossRequest = resolveGlossRequest(body, signLanguage);

    if (!caption) {
      return json({ error: "Missing caption" }, 400);
    }

    let glossSequence;
    let modelUsed;
    try {
      ({ glossSequence, modelUsed } = await captionToGloss(
        caption,
        glossRequest,
        env,
      ));
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

function groqApiKey(env) {
  return env.GROQ_KEY || env.GROQ_API_KEY || "";
}

function groqConfigured(env) {
  return Boolean(groqApiKey(env));
}

function adessoConfigured(env) {
  return Boolean(env.ADESSO_KEY && env.ADESSO_API_URL);
}

function adessoModel(env) {
  return (env.ADESSO_MODEL || "qwen-3.5-122b-sovereign").trim();
}

async function captionToGloss(caption, glossRequest, env) {
  const errors = [];
  const signLanguage = glossRequest.signLanguage;

  if (adessoConfigured(env)) {
    try {
      const glossSequence = validateGlossSequence(
        await captionToGlossAdesso(caption, glossRequest, env),
        signLanguage,
      );
      return {
        glossSequence,
        modelUsed: adessoModel(env),
      };
    } catch (err) {
      errors.push(err);
    }
  }

  if (groqConfigured(env) && !isIslSignLanguage(signLanguage)) {
    try {
      return await captionToGlossGroq(caption, glossRequest, env);
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
          glossRequest,
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

async function captionToGlossGroq(caption, glossRequest, env) {
  const apiKey = groqApiKey(env);
  const model = (env.GROQ_MODEL || "llama-3.1-8b-instant").trim();
  const signLanguage = glossRequest.signLanguage;

  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      ...JSON_HEADERS,
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      temperature: 0,
      max_tokens: 128,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: glossSystemInstruction(glossRequest) },
        { role: "user", content: glossUserMessage(caption, glossRequest) },
      ],
    }),
  });

  if (!res.ok) {
    const detail = await res.text();
    const error = new Error(`Groq ${res.status}: ${detail}`);
    error.status = res.status;
    throw error;
  }

  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content;
  if (!content) {
    throw new Error("Groq returned empty gloss response");
  }

  const glossSequence = validateGlossSequence(parseGloss(content), signLanguage);
  return { glossSequence, modelUsed: `groq:${model}` };
}

async function captionToGlossGemini(
  caption,
  glossRequest,
  env,
  model,
  timeoutMs = 0,
) {
  const apiKey = geminiApiKey(env);
  const signLanguage = glossRequest.signLanguage;
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
        glossRequest,
        apiKey,
        timeoutMs,
      );
      const validated = validateGlossSequence(glossSequence, signLanguage);
      if (isInvalidGlossResponse(validated)) {
        throw new Error("Gemini returned invalid gloss tokens");
      }
      return { glossSequence: validated, modelUsed: resolvedModel };
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

function resolveGlossRequest(body, signLanguage) {
  const languageCode = String(body.languageCode || "")
    .trim()
    .toUpperCase();
  const spokenLanguage = String(body.spokenLanguage || "").trim();
  return {
    signLanguage: signLanguage.trim(),
    languageCode,
    spokenLanguage:
      spokenLanguage || spokenLanguageNameForCode(languageCode),
    scriptHint: scriptHintForCode(languageCode),
  };
}

function spokenLanguageNameForCode(languageCode) {
  switch (languageCode) {
    case "HI":
      return "Hindi";
    case "TA":
      return "Tamil";
    case "ML":
      return "Malayalam";
    case "ENG":
      return "English";
    default:
      return "English";
  }
}

function scriptHintForCode(languageCode) {
  switch (languageCode) {
    case "HI":
      return "Devanagari";
    case "TA":
      return "Tamil";
    case "ML":
      return "Malayalam";
    default:
      return "Latin";
  }
}

function isIslSignLanguage(signLanguage) {
  return signLanguage.trim().toUpperCase().includes("ISL");
}

function glossSystemInstruction(glossRequest) {
  const signLanguage = glossRequest.signLanguage;
  if (isIslSignLanguage(signLanguage)) {
    const spoken = glossRequest.spokenLanguage || "Indian language";
    const script = glossRequest.scriptHint || "native script";
    const code = glossRequest.languageCode || "unknown";
    return (
      `You convert spoken captions into Indian Sign Language (ISL) gloss. ` +
      `The user spoke ${spoken} (languageCode=${code}). ` +
      `The caption is written in ${script} script (or romanized ${spoken}). ` +
      `Read and understand ${spoken}, but ALWAYS output English ISL gloss tokens only. ` +
      `Return JSON only: {"glossSequence":["TOKEN","..."]}. ` +
      `Use UPPERCASE English gloss tokens in an array. ` +
      `NEVER transliterate ${spoken} (no NAMASTE, KYA, APKA, EPPADI, ENGANE, NINGAL, etc.). ` +
      `NEVER use ${script} script or romanized Indic words as tokens. ` +
      `Apply ISL grammar (time → subject → object → verb), not literal English word order. ` +
      `Use ME for first person, YOU for second person. ` +
      `Drop filler words: a, an, the, is, am, are, of, with. ` +
      `Keep numbers, food names, and key nouns. Gloss only the caption fragment. ` +
      `Never return "glossSequence" as a token. ` +
      `Examples (${spoken} input → English ISL output): ` +
      `"I want water" → {"glossSequence":["ME","WANT","WATER"]} ` +
      `"आप कैसे हैं?" (Hindi) → {"glossSequence":["YOU","HOW"]} ` +
      `"நீங்கள் எப்படி இருக்கிறீர்கள்?" (Tamil) → {"glossSequence":["YOU","HOW"]} ` +
      `"നിങ്ങൾ എങ്ങനെയുണ്ട്?" (Malayalam) → {"glossSequence":["YOU","HOW"]} ` +
      `"உங்கள் பெயர் என்ன?" (Tamil) → {"glossSequence":["YOUR","NAME","WHAT"]} ` +
      `"നിങ്ങളുടെ പേരെന്താണ്?" (Malayalam) → {"glossSequence":["YOUR","NAME","WHAT"]} ` +
      `"धन्यवाद" (Hindi) → {"glossSequence":["THANK-YOU"]}`
    );
  }

  return (
    `You convert spoken English into American Sign Language (ASL) gloss. ` +
    `Return JSON only: {"glossSequence":["TOKEN","..."]}. ` +
    `Use UPPERCASE gloss tokens in an array. ` +
    `Apply ASL grammar (topic-comment), NOT word-for-word English. ` +
    `Use ME instead of I. Drop articles (a, an, the) and filler prepositions (of, with) when possible. ` +
    `Keep numbers and important nouns. WH-questions put the WH word last. ` +
    `Gloss only the caption fragment. Never return "glossSequence" as a token. ` +
    `Examples: ` +
    `"how can I help you" → {"glossSequence":["HELP","YOU","HOW"]} ` +
    `"I like dogs" → {"glossSequence":["DOG","ME","LIKE"]} ` +
    `"I want one plate masala dosa with a cup of coffee" → ` +
    `{"glossSequence":["ME","WANT","ONE","MASALA","DOSA","PLATE","COFFEE","CUP"]}`
  );
}

function glossUserMessage(caption, glossRequest) {
  const signLanguage = glossRequest.signLanguage;
  if (isIslSignLanguage(signLanguage)) {
    const spoken = glossRequest.spokenLanguage || "Indian language";
    const script = glossRequest.scriptHint || "native script";
    const code = glossRequest.languageCode || "unknown";
    return (
      `Sign language output: ISL (Indian Sign Language)\n` +
      `Spoken input language: ${spoken} (languageCode=${code})\n` +
      `Caption script: ${script}\n` +
      `Task: Understand the ${spoken} caption below and return English ISL gloss tokens ` +
      `(UPPERCASE English words only, ISL grammar). ` +
      `Do not romanize ${spoken} or copy words from the caption.\n` +
      `Caption:\n${caption}`
    );
  }

  return (
    `Sign language: ${signLanguage.trim()}\n` +
    `Spoken language: ${glossRequest.spokenLanguage || "English"} ` +
    `(languageCode=${glossRequest.languageCode || "ENG"})\n` +
    `Convert this spoken caption into sign gloss using ${signLanguage.trim()} grammar ` +
    `(not literal English word order):\n` +
    `${caption}`
  );
}

const GLOSS_RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    glossSequence: {
      type: "ARRAY",
      items: { type: "STRING" },
      description:
        "ISL: English gloss tokens only (never romanized Hindi/Tamil/Malayalam). ASL/ISL word order. UPPERCASE. No articles or filler.",
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
  glossRequest,
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
          parts: [{ text: glossSystemInstruction(glossRequest) }],
        },
        contents: [
          {
            role: "user",
            parts: [{ text: glossUserMessage(caption, glossRequest) }],
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

async function captionToGlossAdesso(caption, glossRequest, env) {
  const res = await fetch(`${env.ADESSO_API_URL}/chat/completions`, {
    method: "POST",
    headers: {
      ...JSON_HEADERS,
      Authorization: `Bearer ${env.ADESSO_KEY}`,
    },
    body: JSON.stringify({
      model: adessoModel(env),
      temperature: 0.2,
      messages: [
        {
          role: "system",
          content: glossSystemInstruction(glossRequest),
        },
        { role: "user", content: glossUserMessage(caption, glossRequest) },
      ],
    }),
  });

  if (!res.ok) {
    throw new Error(`Adesso ${res.status}: ${await res.text()}`);
  }

  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content ?? "[]";
  return parseGloss(content);
}

function parseGloss(content) {
  const text = String(content).trim();
  const extracted = extractGlossTokens(text);
  if (extracted && extracted.length > 0) {
    return normalizeGlossSequence(extracted);
  }

  throw new Error(`Unable to parse gloss response: ${text.slice(0, 120)}`);
}

function extractGlossTokens(text) {
  try {
    return glossTokensFromParsed(JSON.parse(text));
  } catch (_) {
    // fall through
  }

  const objectMatch = text.match(/\{[\s\S]*"glossSequence"[\s\S]*\}/);
  if (objectMatch) {
    try {
      return glossTokensFromParsed(JSON.parse(objectMatch[0]));
    } catch (_) {
      // fall through
    }
  }

  const arrayMatch = text.match(/\[[\s\S]*\]/);
  if (arrayMatch) {
    try {
      return glossTokensFromParsed(JSON.parse(arrayMatch[0]));
    } catch (_) {
      // fall through
    }
  }

  return null;
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

const JSON_ARTIFACT_TOKENS = new Set(["GLOSSSEQUENCE", "GLOSSEQUENCE"]);

function normalizeGlossSequence(tokens) {
  const normalized = tokens
    .map((token) =>
      String(token)
        .trim()
        .toUpperCase()
        .replace(/[^\w-?]/g, ""),
    )
    .filter((token) => token && !JSON_ARTIFACT_TOKENS.has(token));

  if (normalized.length === 0) {
    throw new Error("Gloss sequence empty after normalization");
  }

  return normalized;
}

function isInvalidGlossResponse(tokens) {
  return !tokens || tokens.length === 0 || tokens.every((token) => JSON_ARTIFACT_TOKENS.has(token));
}

/** Romanized Indic tokens Groq/models emit when they ignore English-ISL instructions. */
const ROMANIZED_ISL_GLOSS = new Set([
  "AJ", "AP", "APAS", "APKA", "APNE", "DHANYAVAAD", "DHANYAWAD",
  "ENGANE", "EPPADI", "GA", "GAYA", "HA", "HAIN", "HO", "HUI",
  "IRUKKIRIRGAL", "KAISA", "KAISI", "KAISE", "KAHAN", "KHANA", "KHAYA",
  "KHUSHI", "KYA", "MIL", "MILENGE", "NAMASTE", "NANDRI", "NINGAL",
  "PHIR", "Q", "RAHE", "RAHI", "RAHTE", "RAHATI", "SHUKRIYA",
  "SWAGAT", "TU", "TUM", "UNGKAL", "VANAKKAM", "VYAST",
]);

function isRomanizedIslGloss(tokens) {
  return tokens.some((token) => ROMANIZED_ISL_GLOSS.has(token));
}

function validateGlossSequence(tokens, signLanguage = "ASL") {
  if (isInvalidGlossResponse(tokens)) {
    throw new Error("Invalid gloss tokens");
  }
  if (isIslSignLanguage(signLanguage) && isRomanizedIslGloss(tokens)) {
    throw new Error("ISL gloss must use English tokens, not romanized Indic");
  }
  return tokens;
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
