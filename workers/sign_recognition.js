/**
 * Shared sign video → spoken text handler for Cloudflare Workers.
 */

const JSON_HEADERS = { "Content-Type": "application/json" };
const MAX_VIDEO_BYTES = 20 * 1024 * 1024;

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

  let text;
  let modelUsed;
  try {
    ({ text, modelUsed } = await videoToSpokenText(
      bytes,
      mimeType,
      languageCode,
      signLanguage,
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

function geminiPrimaryModel(env) {
  return (env.GEMINI_MODEL || "gemini-3.5-flash").trim();
}

function geminiFallbackModel(env) {
  return (env.GEMINI_FALLBACK_MODEL || "gemini-3.1-flash-lite").trim();
}

function geminiModels(env) {
  const primary = geminiPrimaryModel(env);
  const fallback = geminiFallbackModel(env);
  return fallback === primary ? [primary] : [primary, fallback];
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

function signSystemInstruction(signLanguage, languageCode) {
  const sign = signLanguage.trim().toUpperCase();
  const spoken = spokenLanguageName(languageCode);
  return (
    `You translate sign-language video into natural ${spoken} speech text. ` +
    `The person is signing in ${sign}. ` +
    `Return JSON only: {"text":"..."}. ` +
    `Write what they meant to say in ${spoken}, not a scene description. ` +
    `Do not mention hands, camera, or video. ` +
    `If nothing clear was signed, return {"text":""}.`
  );
}

function signUserPrompt(signLanguage, languageCode) {
  const spoken = spokenLanguageName(languageCode);
  return (
    `Watch this ${signLanguage.trim()} signing video and write the ${spoken} ` +
    `sentence the signer intended to communicate.`
  );
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
  env,
) {
  const apiKey = geminiApiKey(env);
  if (!apiKey) {
    throw new Error("GEMINI_KEY not configured");
  }

  const errors = [];
  for (const model of geminiModels(env)) {
    try {
      return await requestGeminiSignText(
        model,
        bytes,
        mimeType,
        languageCode,
        signLanguage,
        apiKey,
      );
    } catch (err) {
      errors.push(err);
      if (isModelUnavailableStatus(err.status || 0)) {
        continue;
      }
    }
  }

  const detail = errors.map((err) => String(err).slice(0, 80)).join(" | ");
  throw new Error(detail || "Gemini sign recognition failed");
}

async function requestGeminiSignText(
  model,
  bytes,
  mimeType,
  languageCode,
  signLanguage,
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
        apiKey,
      );
      if (!text.trim()) {
        throw new Error("Gemini returned empty sign text");
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
        parts: [{ text: signSystemInstruction(signLanguage, languageCode) }],
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
            { text: signUserPrompt(signLanguage, languageCode) },
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
    throw new Error("Gemini returned empty sign response");
  }

  return parseSignText(content);
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
