/**
 * Maps gloss tokens → R2 clip keys using manifest.json (asl/isl + aliases).
 */

const CANONICAL_ALIASES = {
  hi: "hello",
  hey: "hello",
  thanks: "thank_you",
  thank: "thank_you",
  thank_you: "thank_you",
  excuse_me: "excuse_me",
  pass_me: "pass_me",
  wake_up: "wake_up",
  cannot: "cannot",
  can_not: "cannot",
  dont: "no",
  do_not: "no",
  not: "no",
  pls: "please",
  okay: "good",
  ok: "good",
  fine: "good",
};

export function languageKeyForSignLanguage(signLanguage) {
  const lang = (signLanguage || "ASL").trim().toUpperCase();
  return lang.includes("ISL") ? "isl" : "asl";
}

export function normalizeGlossKey(raw) {
  return (raw || "")
    .trim()
    .toUpperCase()
    .replace(/\s+/g, "-")
    .replace(/_/g, "-")
    .replace(/[^A-Z0-9-]/g, "")
    .toLowerCase()
    .replace(/-/g, "_");
}

export function canonicalGlossKey(raw) {
  const normalized = normalizeGlossKey(raw);
  return CANONICAL_ALIASES[normalized] || normalized;
}

export function glossLookupKeys(gloss) {
  const seen = new Set();
  const keys = [];
  const add = (value) => {
    const trimmed = (value || "").trim();
    if (!trimmed || seen.has(trimmed)) {
      return;
    }
    seen.add(trimmed);
    keys.push(trimmed);
  };

  add(gloss);
  add(gloss.replace(/[?!]+$/, ""));
  add(normalizeGlossKey(gloss));
  add(canonicalGlossKey(gloss));
  return keys;
}

function readLanguageMap(value) {
  if (!value || typeof value !== "object") {
    return {};
  }
  const entries = {};
  for (const [key, rawPath] of Object.entries(value)) {
    const path = readAssetPath(rawPath);
    if (path) {
      entries[key] = path;
    }
  }
  return entries;
}

function readAssetPath(value) {
  if (typeof value === "string" && value.trim()) {
    return value.trim();
  }
  if (value && typeof value === "object" && typeof value.path === "string") {
    return value.path.trim();
  }
  return null;
}

export function parseManifest(manifest) {
  if (!manifest || typeof manifest !== "object") {
    throw new Error("Invalid manifest");
  }
  const version = manifest.version;
  if (typeof version !== "number" || version < 1) {
    throw new Error(`Unsupported manifest version: ${version}`);
  }
  return {
    entries: {
      asl: readLanguageMap(manifest.asl),
      isl: readLanguageMap(manifest.isl),
    },
    aliases: {
      asl: readLanguageMap(manifest.aliases?.asl),
      isl: readLanguageMap(manifest.aliases?.isl),
    },
  };
}

function resolveManifestPath(language, key, entries, aliases) {
  const direct = entries[key];
  if (direct) {
    return direct;
  }

  const aliasTarget = aliases[key];
  if (aliasTarget && entries[aliasTarget]) {
    return entries[aliasTarget];
  }

  const canonical = canonicalGlossKey(key);
  if (canonical !== key && entries[canonical]) {
    return entries[canonical];
  }
  return null;
}

export function assetPathToR2Key(assetPath) {
  const trimmed = (assetPath || "").trim();
  if (!trimmed) {
    return null;
  }
  const withoutPrefix = trimmed
    .replace(/^\/+/, "")
    .replace(/^assets\/signs\//, "");
  if (!/^(asl|isl)\/.+\.mp4$/i.test(withoutPrefix)) {
    return null;
  }
  return withoutPrefix;
}

/**
 * @returns {{ keys: string[], assetPaths: string[], missing: string[] }}
 */
export function resolveGlossClipPaths(manifest, signLanguage, glossSequence) {
  const { entries, aliases } = parseManifest(manifest);
  const language = languageKeyForSignLanguage(signLanguage);
  const languageEntries = entries[language] || {};
  const languageAliases = aliases[language] || {};

  const keys = [];
  const assetPaths = [];
  const missing = [];
  let lastKey = null;

  for (const rawGloss of glossSequence || []) {
    const gloss = `${rawGloss || ""}`.trim().toUpperCase();
    if (!gloss || gloss === "GLOSSSEQUENCE" || gloss === "GLOSSEQUENCE") {
      continue;
    }

    let assetPath = null;
    for (const key of glossLookupKeys(gloss)) {
      assetPath = resolveManifestPath(
        language,
        key,
        languageEntries,
        languageAliases,
      );
      if (assetPath) {
        break;
      }
    }

    if (!assetPath) {
      missing.push(gloss);
      continue;
    }

    const r2Key = assetPathToR2Key(assetPath);
    if (!r2Key) {
      missing.push(gloss);
      continue;
    }

    if (r2Key === lastKey) {
      continue;
    }
    lastKey = r2Key;
    keys.push(r2Key);
    assetPaths.push(assetPath);
  }

  return { keys, assetPaths, missing };
}
