import { buildSignVideoPrompt, veoParameters } from "../workers/veo_sign_video.js";

function assertIncludes(text, needle) {
  if (!text.includes(needle)) {
    throw new Error(`Expected prompt to include "${needle}"`);
  }
}

const prompt = buildSignVideoPrompt({
  caption: "hello how are you",
  glossSequence: ["HELLO", "HOW", "YOU"],
  signLanguage: "ASL",
  avatarMode: "genasl",
});

assertIncludes(prompt, "American Sign Language");
assertIncludes(prompt, "GenASL-style");
assertIncludes(prompt, "HELLO HOW YOU");
assertIncludes(prompt, "gloss-first");
assertIncludes(prompt, "light gray studio background");

const params = veoParameters({ VEO_ASPECT_RATIO: "9:16", VEO_RESOLUTION: "720p" });
if (params.aspectRatio !== "9:16" || params.resolution !== "720p") {
  throw new Error("Unexpected default Veo parameters");
}

console.log("veo_sign_video prompt tests passed");
