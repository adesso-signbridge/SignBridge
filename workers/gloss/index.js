/**
 * SignBridge gloss Worker — POST { caption, signLanguage } → glossSequence[].
 * Secrets: GEMINI_KEY (or GEMINI_API_KEY), ADESSO_KEY, ADESSO_API_URL, WORKER_SHARED_KEY.
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

function glossProvider(env) {
  const configured = (env.GLOSS_PROVIDER || "gemini").trim().toLowerCase();
  if (configured === "adesso" && env.ADESSO_KEY && env.ADESSO_API_URL) {
    return "adesso";
  }
  if (geminiApiKey(env)) {
    return "gemini";
  }
  if (env.ADESSO_KEY && env.ADESSO_API_URL) {
    return "adesso";
  }
  return configured;
}

async function captionToGloss(caption, signLanguage, env) {
  const provider = glossProvider(env);
  if (provider === "adesso") {
    const glossSequence = await captionToGlossAdesso(caption, signLanguage, env);
    return { glossSequence, modelUsed: env.ADESSO_MODEL || "qwen-3.6-35b-sovereign" };
  }
  return captionToGlossGemini(caption, signLanguage, env);
}

function geminiModelChain(env) {
  const primary = (env.GEMINI_MODEL || "gemini-3.5-flash").trim();
  const fallbacks = (env.GEMINI_FALLBACK_MODELS || "gemini-2.0-flash,gemini-1.5-flash")
    .split(",")
    .map((model) => model.trim())
    .filter(Boolean);
  return [...new Set([primary, ...fallbacks])];
}

function isRetryableGeminiStatus(status) {
  return status === 429 || status === 500 || status === 503 || status === 504;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function captionToGlossGemini(caption, signLanguage, env) {
  const apiKey = geminiApiKey(env);
  if (!apiKey) {
    throw new Error("GEMINI_KEY not configured");
  }

  const models = geminiModelChain(env);
  let lastError = null;

  for (const model of models) {
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        const glossSequence = await requestGeminiGloss(
          model,
          caption,
          signLanguage,
          apiKey,
        );
        return { glossSequence, modelUsed: model };
      } catch (err) {
        lastError = err;
        const status = err.status || 0;
        if (!isRetryableGeminiStatus(status) || attempt === 2) {
          break;
        }
        await sleep(400 * (attempt + 1));
      }
    }
  }

  throw lastError || new Error("Gemini request failed");
}

function glossSystemInstruction(signLanguage) {
  return (
    `You are a professional translation engine that converts spoken-language ` +
    `captions into ${signLanguage} sign language gloss tokens. Reply only with ` +
    `JSON matching the provided schema. Each gloss token must be a single ` +
    `UPPERCASE word with no punctuation. Preserve semantic order appropriate ` +
    `for ${signLanguage}. Do not include explanations, markdown, or prose.`
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
        maxOutputTokens: 256,
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
  if (extracted) {
    return normalizeGlossSequence(extracted);
  }

  return normalizeGlossSequence(
    text
      .replace(/[\[\]"]/g, "")
      .split(/[\s,]+/)
      .filter(Boolean),
  );
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
  if (parsed && Array.isArray(parsed.glossSequence)) {
    return parsed.glossSequence;
  }
  return null;
}

function normalizeGlossSequence(tokens) {
  const normalized = tokens
    .map((token) =>
      String(token)
        .trim()
        .toUpperCase()
        .replace(/[^\w-]/g, ""),
    )
    .filter(Boolean);

  if (normalized.length === 0) {
    throw new Error("Gloss sequence empty after normalization");
  }

  return normalized;
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
