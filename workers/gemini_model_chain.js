/**
 * Gemini model failover ordered best quality → lowest.
 *
 * 1. Primary (GEMINI_MODEL / SIGN_GEMINI_MODEL, default gemini-3.5-flash)
 * 2. gemini-3-flash-preview (API id for Gemini 3 Flash)
 * 3. GEMINI_FALLBACK_MODEL / SIGN_GEMINI_FALLBACK_MODEL (default gemini-2.5-flash)
 * 4. GEMINI_LITE_MODEL (default gemini-3.1-flash-lite)
 * 5. GEMINI_LITE_FALLBACK_MODEL (default gemini-2.5-flash-lite)
 */

export function uniqueGeminiModels(models) {
  const seen = new Set();
  const resolved = [];
  for (const model of models) {
    const trimmed = (model || "").trim();
    if (!trimmed || seen.has(trimmed)) {
      continue;
    }
    seen.add(trimmed);
    resolved.push(trimmed);
  }
  return resolved;
}

export function geminiQualityChain(env, { primaryVar = "GEMINI_MODEL" } = {}) {
  const primary = (
    env[primaryVar] ||
    env.GEMINI_MODEL ||
    env.SIGN_GEMINI_MODEL ||
    "gemini-3.5-flash"
  ).trim();

  const flash25 = (
    env.GEMINI_FALLBACK_MODEL ||
    env.SIGN_GEMINI_FALLBACK_MODEL ||
    "gemini-2.5-flash"
  ).trim();

  const lite31 = (env.GEMINI_LITE_MODEL || "gemini-3.1-flash-lite").trim();
  const lite25 = (env.GEMINI_LITE_FALLBACK_MODEL || "gemini-2.5-flash-lite").trim();

  return uniqueGeminiModels([
    primary,
    "gemini-3-flash-preview",
    flash25,
    lite31,
    lite25,
  ]);
}
