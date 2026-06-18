import { handleSignRecognitionRequest } from "../sign_recognition.js";

export default {
  async fetch(request, env) {
    return handleSignRecognitionRequest(request, env);
  },
};
