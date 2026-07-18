import {
  bananaImageConfig,
  buildGlossImagePrompt,
} from "../workers/gemini_gloss_image.js";

function assertIncludes(text, needle) {
  if (!text.includes(needle)) {
    throw new Error(`Expected prompt to include "${needle}"`);
  }
}

const prompt = buildGlossImagePrompt({
  gloss: "HELLO",
  signLanguage: "ASL",
});

assertIncludes(prompt, "American Sign Language");
assertIncludes(prompt, "HELLO");
assertIncludes(prompt, "2D illustration");
assertIncludes(prompt, "light gray studio background");

const islPrompt = buildGlossImagePrompt({
  gloss: "THANK-YOU",
  signLanguage: "ISL",
});
assertIncludes(islPrompt, "Indian Sign Language");
assertIncludes(islPrompt, "THANK-YOU");

const config = bananaImageConfig({ BANANA_ASPECT_RATIO: "3:4" });
if (config.aspectRatio !== "3:4") {
  throw new Error("Unexpected default Banana aspect ratio");
}

console.log("gemini_gloss_image prompt tests passed");
