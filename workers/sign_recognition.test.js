import assert from "node:assert/strict";
import test from "node:test";

import { captionToGlossGroq, groqConfigured } from "./gloss_providers.js";
import { scoreRecognitionResult } from "./sign_recognition.js";

test("scoreRecognitionResult rewards fuller gloss sequences", () => {
  const short = scoreRecognitionResult(["HELLO"], "Hi.", 4000, "");
  const full = scoreRecognitionResult(
    ["MY", "NAME", "ALEX", "ME", "DEAF"],
    "My name is Alex. I am deaf.",
    4000,
    "",
  );
  assert.ok(full > short);
});

test("groqConfigured requires API key", () => {
  assert.equal(groqConfigured({}), false);
  assert.equal(groqConfigured({ GROQ_KEY: "test" }), true);
});

test("captionToGlossGroq sends expected request shape", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    assert.equal(url, "https://api.groq.com/openai/v1/chat/completions");
    const body = JSON.parse(init.body);
    assert.equal(body.model, "llama-3.1-8b-instant");
    assert.equal(body.response_format.type, "json_object");
    return new Response(
      JSON.stringify({
        choices: [
          {
            message: {
              content: '{"glossSequence":["ME","FINE"]}',
            },
          },
        ],
      }),
      { status: 200 },
    );
  };

  try {
    const result = await captionToGlossGroq("I am fine", "ASL", {
      GROQ_KEY: "secret",
      GROQ_MODEL: "llama-3.1-8b-instant",
    });
    assert.deepEqual(result.glossSequence, ["ME", "FINE"]);
    assert.equal(result.modelUsed, "groq:llama-3.1-8b-instant");
  } finally {
    globalThis.fetch = originalFetch;
  }
});
