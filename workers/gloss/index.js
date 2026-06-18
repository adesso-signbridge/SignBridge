/**
 * SignBridge gloss Worker — POST { caption, signLanguage } → glossSequence[].
 * Provider chain: Groq → Gemini 3.1 Flash-Lite → Adesso (local fallback in app).
 * Secrets: GROQ_KEY, GEMINI_KEY, ADESSO_KEY, ADESSO_API_URL, WORKER_SHARED_KEY.
 */

const JSON_HEADERS = { "Content-Type": "application/json" };

export default {
  async fetch(request, env) {
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

function groqApiKey(env) {
  return env.GROQ_KEY || env.GROQ_API_KEY || "";
}

function groqConfigured(env) {
  return Boolean(groqApiKey(env));
}

function adessoConfigured(env) {
  return Boolean(env.ADESSO_KEY && env.ADESSO_API_URL);
}

async function captionToGloss(caption, signLanguage, env) {
  const errors = [];

  if (groqConfigured(env)) {
    try {
      return await captionToGlossGroq(caption, signLanguage, env);
    } catch (err) {
      errors.push(err);
    }
  }

  if (geminiApiKey(env)) {
    try {
      return await captionToGlossGemini(caption, signLanguage, env);
    } catch (err) {
      errors.push(err);
    }
  }

  if (adessoConfigured(env)) {
    try {
      const glossSequence = validateGlossSequence(
        await captionToGlossAdesso(caption, signLanguage, env),
      );
      return {
        glossSequence,
        modelUsed: env.ADESSO_MODEL || "qwen-3.6-35b-sovereign",
      };
    } catch (err) {
      errors.push(err);
    }
  }

  const detail = errors.map((err) => String(err).slice(0, 80)).join(" | ");
  throw new Error(detail || "No gloss provider configured");
}

function geminiModel(env) {
  return (env.GEMINI_MODEL || "gemini-3.1-flash-lite").trim();
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

async function captionToGlossGroq(caption, signLanguage, env) {
  const apiKey = groqApiKey(env);
  const model = (env.GROQ_MODEL || "llama-3.1-8b-instant").trim();

  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      ...JSON_HEADERS,
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      temperature: 0,
      max_tokens: 96,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: glossSystemInstruction(signLanguage) },
        { role: "user", content: caption },
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

  const glossSequence = validateGlossSequence(parseGloss(content));
  return { glossSequence, modelUsed: `groq:${model}` };
}

async function captionToGlossGemini(caption, signLanguage, env) {
  const apiKey = geminiApiKey(env);
  if (!apiKey) {
    throw new Error("GEMINI_KEY not configured");
  }

  const model = geminiModel(env);
  let lastError = null;

  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const glossSequence = await requestGeminiGloss(
        model,
        caption,
        signLanguage,
        apiKey,
      );
      if (isInvalidGlossResponse(glossSequence)) {
        throw new Error("Gemini returned invalid gloss tokens");
      }
      return { glossSequence, modelUsed: model };
    } catch (err) {
      lastError = err;
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

function glossSystemInstruction(signLanguage) {
  return (
    `Convert the spoken caption into ${signLanguage} sign gloss tokens. ` +
    `Return JSON with glossSequence as an array of UPPERCASE words only ` +
    `(example: {"glossSequence":["HOW","CAN","HELP","YOU"]}). ` +
    `Do not return the key name as a token. Gloss only the caption fragment.`
  );
}

const GLOSS_RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    glossSequence: {
      type: "ARRAY",
      items: { type: "STRING" },
      description:
        "Sign language gloss tokens in strict sequential order. All strings must be UPPERCASE.",
      minItems: 1,
    },
  },
  required: ["glossSequence"],
  propertyOrdering: ["glossSequence"],
};

async function requestGeminiGloss(model, caption, signLanguage, apiKey) {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}` +
    `:generateContent?key=${encodeURIComponent(apiKey)}`;

  const res = await fetch(url, {
    method: "POST",
    headers: JSON_HEADERS,
    body: JSON.stringify({
      systemInstruction: {
        parts: [{ text: glossSystemInstruction(signLanguage) }],
      },
      contents: [
        {
          role: "user",
          parts: [{ text: caption }],
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

async function captionToGlossAdesso(caption, signLanguage, env) {
  const res = await fetch(`${env.ADESSO_API_URL}/chat/completions`, {
    method: "POST",
    headers: {
      ...JSON_HEADERS,
      Authorization: `Bearer ${env.ADESSO_KEY}`,
    },
    body: JSON.stringify({
      model: env.ADESSO_MODEL || "qwen-3.6-35b-sovereign",
      temperature: 0.2,
      messages: [
        {
          role: "system",
          content: glossSystemInstruction(signLanguage),
        },
        { role: "user", content: caption },
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

function validateGlossSequence(tokens) {
  if (isInvalidGlossResponse(tokens)) {
    throw new Error("Invalid gloss tokens");
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
