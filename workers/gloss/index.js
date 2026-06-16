/**
 * SignBridge gloss Worker.
 *
 * Flow:
 *   1. Flutter writes a caption job to RTDB (status: CAPTION_READY).
 *   2. Flutter POSTs { jobId, caption, signLanguage } to this Worker.
 *   3. Worker asks Adesso AI to convert the caption into sign gloss tokens.
 *   4. Worker PATCHes RTDB caption_jobs/{jobId} -> status: GLOSS_READY.
 *
 * Secrets (set in Cloudflare dashboard -> Settings -> Variables and secrets):
 *   - ADESSO_KEY          (required)
 *   - ADESSO_API_URL      (required)
 *   - FIREBASE_DB_SECRET  (optional; only to write back to RTDB)
 *   - WORKER_SHARED_KEY   (optional; if set, callers must send it)
 *
 * Plain vars (already in wrangler.toml):
 *   - ADESSO_MODEL, FIREBASE_DB_URL, CAPTION_JOBS_PATH
 */

const JSON_HEADERS = { "Content-Type": "application/json" };

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    // Optional shared-key gate so the public URL can't be abused.
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

    const jobId = (body.jobId || "").trim();
    const caption = (body.caption || "").trim();
    const signLanguage = (body.signLanguage || "ASL").trim();

    if (!jobId || !caption) {
      return json({ error: "Missing jobId or caption" }, 400);
    }

    let glossSequence;
    try {
      glossSequence = await captionToGloss(caption, signLanguage, env);
    } catch (err) {
      await patchJob(jobId, env, {
        status: "FAILED",
        errorMessage: String(err).slice(0, 300),
        updatedAt: Date.now(),
      });
      return json({ error: "AI request failed", detail: String(err) }, 502);
    }

    // Writing back to RTDB is optional. If FIREBASE_DB_SECRET is configured the
    // Worker updates the job to GLOSS_READY; otherwise the app takes the gloss
    // from this response and writes / plays it itself.
    let rtdbWritten = false;
    if (env.FIREBASE_DB_SECRET) {
      try {
        await patchJob(jobId, env, {
          status: "GLOSS_READY",
          glossSequence,
          updatedAt: Date.now(),
        });
        rtdbWritten = true;
      } catch (err) {
        return json({ error: "RTDB write failed", detail: String(err) }, 502);
      }
    }

    return json({ ok: true, jobId, glossSequence, rtdbWritten });
  },
};

async function captionToGloss(caption, signLanguage, env) {
  const res = await fetch(`${env.ADESSO_API_URL}/chat/completions`, {
    method: "POST",
    headers: {
      ...JSON_HEADERS,
      Authorization: `Bearer ${env.ADESSO_KEY}`,
    },
    body: JSON.stringify({
      model: env.ADESSO_MODEL,
      temperature: 0.2,
      messages: [
        {
          role: "system",
          content:
            `You convert spoken-language captions into ${signLanguage} sign ` +
            `language gloss. Reply with ONLY a JSON array of UPPERCASE gloss ` +
            `tokens, no prose. Example: ["HELLO","HOW","YOU"].`,
        },
        { role: "user", content: caption },
      ],
    }),
  });

  if (!res.ok) {
    throw new Error(`Adesso AI ${res.status}: ${await res.text()}`);
  }

  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content ?? "[]";
  return parseGloss(content);
}

function parseGloss(content) {
  const text = String(content).trim();

  // Try direct JSON array first.
  try {
    const parsed = JSON.parse(text);
    if (Array.isArray(parsed)) {
      return parsed.map((t) => String(t).toUpperCase());
    }
  } catch (_) {
    // fall through
  }

  // Try to extract a [...] block from surrounding text.
  const match = text.match(/\[[\s\S]*\]/);
  if (match) {
    try {
      const parsed = JSON.parse(match[0]);
      if (Array.isArray(parsed)) {
        return parsed.map((t) => String(t).toUpperCase());
      }
    } catch (_) {
      // fall through
    }
  }

  // Last resort: split words.
  return text
    .replace(/[\[\]"]/g, "")
    .split(/[\s,]+/)
    .filter(Boolean)
    .map((t) => t.toUpperCase());
}

async function patchJob(jobId, env, patch) {
  const path = env.CAPTION_JOBS_PATH || "caption_jobs";
  const url =
    `${env.FIREBASE_DB_URL}/${path}/${jobId}.json` +
    `?auth=${encodeURIComponent(env.FIREBASE_DB_SECRET)}`;

  const res = await fetch(url, {
    method: "PATCH",
    headers: JSON_HEADERS,
    body: JSON.stringify(patch),
  });

  if (!res.ok) {
    throw new Error(`RTDB ${res.status}: ${await res.text()}`);
  }
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: JSON_HEADERS });
}
