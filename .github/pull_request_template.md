## Summary

<!-- Briefly describe what this PR changes and why. -->

-

## What changed

<!-- Check everything this PR includes. -->

- [ ] Talk listen session (speech → live caption → gloss → avatar)
- [ ] Speech-to-text / caption pipeline
- [ ] Sign avatar (Android / iOS native)
- [ ] UI / Figma layout updates
- [ ] Tests added or updated
- [ ] README or docs updated
- [ ] CI / build configuration
- [ ] Other: <!-- describe -->

## Device testing

<!-- Real-device verification is required for Talk / speech features. -->

### Android

- [ ] Tested on a physical Android device (model: <!-- e.g. Samsung Galaxy S25 -->)
- [ ] Microphone permission granted
- [ ] Tap **Listen** → live caption appears while speaking
- [ ] Long / multi-sentence speech with short pauses → caption keeps growing
- [ ] Tap **Stop** once → session ends, transcript shown on stopped screen
- [ ] No mic restart after **Stop** (no unwanted listening in logs)
- [ ] **Clear history** returns to idle
- [ ] Waveform reacts to voice (not stuck flat or pegged)
- [ ] Sign avatar / gloss chip updates for spoken words

### iOS

- [ ] Tested on a physical iOS device (model: <!-- e.g. iPhone 15 -->)
- [ ] Microphone & speech recognition permission granted
- [ ] Tap **Listen** → live caption appears while speaking
- [ ] Tap **Stop** once → stopped screen with transcript
- [ ] **Clear history** returns to idle
- [ ] Sign avatar / gloss chip behaves as expected

### Languages (if changed)

- [ ] English → ASL
- [ ] Hindi / Tamil / Malayalam → ISL
- [ ] Not tested (explain why)

## Automated checks

<!-- Confirm before merge. CI runs on PRs to `main`. -->

- [ ] `dart format --output=none --set-exit-if-changed .` passes
- [ ] `flutter analyze --fatal-infos --fatal-warnings` passes
- [ ] `flutter test --exclude-tags store-blocker` passes
- [ ] GitHub Actions CI green on this PR
- [ ] No secrets or forbidden files committed

## Screenshots / recordings (optional)

<!-- Attach device screenshots or screen recordings for UI or caption behaviour. -->

## Known issues / follow-ups

<!-- List anything not fixed in this PR, or items for a later ticket. -->

-

## Reviewer notes

<!-- Anything reviewers should focus on. -->

-
