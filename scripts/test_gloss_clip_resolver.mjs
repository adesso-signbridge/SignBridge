import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import {
  resolveGlossClipPaths,
  normalizeGlossKey,
} from "../workers/gloss_clip_resolver.js";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const manifest = JSON.parse(
  readFileSync(join(root, "assets/signs/manifest.json"), "utf8"),
);

assert.equal(normalizeGlossKey("THANK YOU"), "thank_you");

const resolved = resolveGlossClipPaths(manifest, "ASL", [
  "HELLO",
  "HOW",
  "YOU",
]);
assert.ok(resolved.keys.length >= 2, "expected at least 2 clips");
assert.ok(
  resolved.keys.every((key) => /^(asl|isl)\/.+\.mp4$/.test(key)),
  "keys must be R2 paths",
);
assert.equal(resolved.missing.length, 0);

console.log("gloss_clip_resolver tests passed");
