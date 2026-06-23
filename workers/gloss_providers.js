/**
 * Shared caption → ASL/ISL gloss providers (Groq primary, Adesso fallback).
 */

export const JSON_HEADERS = { "Content-Type": "application/json" };

const JSON_ARTIFACT_TOKENS = new Set(["GLOSSSEQUENCE", "GLOSSEQUENCE"]);

export function groqApiKey(env) {
  return env.GROQ_KEY || env.GROQ_API_KEY || "";
}

export function groqConfigured(env) {
  return Boolean(groqApiKey(env));
}

export function adessoConfigured(env) {
  return Boolean(env.ADESSO_KEY && env.ADESSO_API_URL);
}

export function adessoModel(env) {
  return (env.ADESSO_MODEL || "qwen-3.6-35b-sovereign").trim();
}

export function glossSystemInstruction(signLanguage) {
  const lang = signLanguage.trim().toUpperCase();
  if (lang.includes("ISL")) {
    return (
      `You convert spoken captions into Indian Sign Language (ISL) gloss. ` +
      `Return JSON only: {"glossSequence":["TOKEN","..."]}. ` +
      `Use UPPERCASE gloss tokens separated in an array. ` +
      `Apply ISL grammar, not literal English word order. ` +
      `Use ME for first person. Drop filler words: a, an, the, is, am, are, of, with. ` +
      `Keep numbers, food names, and key nouns. Gloss only the caption fragment. ` +
      `Never return "glossSequence" as a token. ` +
      `Example: "I want water" → {"glossSequence":["ME","WANT","WATER"]}`
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

export function glossUserMessage(caption, signLanguage) {
  return (
    `Sign language: ${signLanguage.trim()}\n` +
    `Convert this spoken caption into sign gloss using ${signLanguage.trim()} grammar ` +
    `(not literal English word order):\n` +
    `${caption}`
  );
}

export async function captionToGlossGroq(caption, signLanguage, env) {
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
      max_tokens: 128,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: glossSystemInstruction(signLanguage) },
        { role: "user", content: glossUserMessage(caption, signLanguage) },
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

export async function captionToGlossAdesso(caption, signLanguage, env) {
  const model = adessoModel(env);
  const res = await fetch(`${env.ADESSO_API_URL}/chat/completions`, {
    method: "POST",
    headers: {
      ...JSON_HEADERS,
      Authorization: `Bearer ${env.ADESSO_KEY}`,
    },
    body: JSON.stringify({
      model,
      temperature: 0.2,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content: glossSystemInstruction(signLanguage),
        },
        { role: "user", content: glossUserMessage(caption, signLanguage) },
      ],
    }),
  });

  if (!res.ok) {
    const error = new Error(`Adesso ${res.status}: ${await res.text()}`);
    error.status = res.status;
    throw error;
  }

  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content ?? "[]";
  const glossSequence = validateGlossSequence(parseGloss(content));
  return { glossSequence, modelUsed: `adesso:${model}` };
}

/** Groq first, then Adesso — for caption or recognized spoken text → gloss. */
export async function captionToGloss(caption, signLanguage, env) {
  const errors = [];

  if (groqConfigured(env)) {
    try {
      return await captionToGlossGroq(caption, signLanguage, env);
    } catch (err) {
      errors.push(err);
    }
  }

  if (adessoConfigured(env)) {
    try {
      return await captionToGlossAdesso(caption, signLanguage, env);
    } catch (err) {
      errors.push(err);
    }
  }

  const detail = errors.map((err) => String(err).slice(0, 80)).join(" | ");
  throw new Error(detail || "No gloss provider configured (set GROQ_KEY or ADESSO_KEY)");
}

export function parseGloss(content) {
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
  return (
    !tokens ||
    tokens.length === 0 ||
    tokens.every((token) => JSON_ARTIFACT_TOKENS.has(token))
  );
}

function validateGlossSequence(tokens) {
  if (isInvalidGlossResponse(tokens)) {
    throw new Error("Invalid gloss tokens");
  }
  return tokens;
}
