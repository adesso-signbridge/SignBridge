# SignBridge

SignBridge is a mobile accessibility app that helps **deaf** and **mute (non-verbal)** people communicate in everyday life. Using the phone, they can **hear** what others say and **reply** back — without needing to speak or read lips.

Built by [adesso](https://www.adesso.de/).

### Who it is for

| User need | How SignBridge helps |
|-----------|----------------------|
| **Deaf / hard of hearing** | Others speak into the app → SignBridge shows sign language (or text) so the user can *hear* and understand the conversation. |
| **Mute / non-verbal** | The user signs or selects phrases in the app → SignBridge speaks the message out loud so they can *reply* and be understood. |

SignBridge removes the communication barrier between spoken language and sign language, so deaf and mute users can take part in conversations at shops, hospitals, work, and home.

## What the app does

SignBridge provides two core translation modes:

| Mode | Direction | Description |
|------|-----------|-------------|
| **Hear for me** | Voice → Sign | Someone speaks into the phone; the app converts speech into sign language so a deaf user can *hear* and understand. |
| **Speak for me** | Sign → Voice | The user signs or taps a phrase; the app converts it into spoken words so a mute user can *reply* and be heard. |

The app is organized around five main areas:

- **Talk** — Live listen session: speech → caption → ASL/ISL gloss → 3D signing avatar.
- **Phrases** — Saved and frequently used phrases for faster communication.
- **SOS** — Emergency communication tools for urgent situations.
- **Settings** — App preferences, language, and accessibility options.

> **Current status:** Talk listen flow (speech capture, live captions, ASL/ISL gloss, native 3D avatar) is implemented on Android and iOS. Phrases, SOS, and remote backend services are scaffolded with local adapters.

## Talk listen flow

```
Tap Listen  → mic permission → speech-to-text (device)
            → live caption (scrollable bubble, top)
            → ASL/ISL gloss chip + native 3D avatar (latest word)
            → mic waveform (live audio level)
Tap Stop    → full transcript on stopped screen (or “No speech detected”)
Clear       → return to idle
```

### Session behaviour

| Action | What happens |
|--------|----------------|
| **Listen** | Starts a dictation session. Partial results update the caption in real time. |
| **Pause while speaking** | After ~10s silence the OS ends the current chunk; the app commits that phrase and auto-resumes listening so longer conversations can continue. |
| **Stop** | One tap ends the session, flushes the final transcript, and shows the stopped screen. |
| **Clear history** | Discards the stopped transcript and returns to the idle Talk screen. |

### Captions

Live captions use the same model as common `speech_to_text` continuous-listen apps:

- **Committed lines** — finalized phrases from each listen chunk or final result.
- **Current hypothesis** — the recognizer’s in-progress `recognizedWords` for the active chunk.
- **Display** — `committed + hypothesis`, in a scrollable bubble that follows the latest words.

This supports multi-sentence and multi-pause conversations without dropping earlier text.

### Sign mapping

| Spoken language | Sign system |
|-----------------|-------------|
| English (ENG)   | ASL         |
| Hindi, Tamil, Malayalam | ISL |

The gloss lexicon is a starter set; unknown words appear as uppercase fallback glosses on the avatar chip.

### Permissions and testing

- **Permissions:** microphone and speech recognition (iOS `Info.plist`, Android `RECORD_AUDIO`).
- **Physical device recommended** for real STT and avatar rendering (Samsung/Google recognizers behave differently from emulators).
- **Simulator / CI:** tests use a mock speech pipeline (`LocalTranslateService(forceMockListening: true)`).

## Technology stack

| Layer | Technology |
|-------|------------|
| Framework | [Flutter](https://flutter.dev/) |
| Language | Dart 3.12+ |
| UI | Material Design, custom Figma-based theme |
| Speech | `speech_to_text`, `permission_handler` |
| 3D avatar | Native SceneKit (iOS), Canvas 3D (Android) via platform views |
| Assets | PNG icons, SVG logos (`flutter_svg`) |
| Typography | Klavika Bold (brand font) |
| Platforms | Android, iOS (scaffold also includes web, macOS, Linux, Windows) |
| Testing | `flutter_test` widget + service tests, architecture guardrails, release readiness |
| CI | GitHub Actions — **PR merge gate** (5 checks: coding standards, architecture, tests, Android build, iOS checks) |

## Architecture

The app follows a **feature-first layout** with a **microservice-oriented client architecture**. Each domain (home, translate, phrases, SOS, settings, splash) is an independent module that can talk to its own backend service when available.

```
lib/
├── main.dart                         # Bootstrap ServiceLocator, run app
├── app/                              # Root MaterialApp
├── core/
│   ├── di/service_locator.dart       # Dependency injection registry
│   ├── platform/                     # Mic permission, avatar widgets
│   ├── services/microservice.dart
│   └── theme/
├── features/
│   ├── splash/presentation/
│   ├── home/presentation/            # Talk screen + session UI
│   └── shared/presentation/
├── services/
│   ├── home/                         # HomeService + localized UI copy
│   ├── translate/                    # STT, transcript merge, ASL/ISL catalog
│   ├── phrases/, sos/, settings/, splash/
└── shell/main_shell.dart
```

### Key design decisions

1. **Service interfaces + adapters** — UI depends on abstractions (`TranslateService`, `HomeService`). Local implementations ship today; remote adapters swap in without UI changes.

2. **Session generation tokens** — `HomeScreen` uses monotonic generation counters so async listen/stop/clear races cannot apply stale UI updates.

3. **Transcript accumulator** — `SpeechTranscriptAccumulator` keeps committed phrase lines separate from the live STT hypothesis, matching how continuous dictation apps handle pause/resume on Android and iOS.

4. **CWASA avatar** — `CwasaAvatarView` renders SiGML signing on device; Flutter falls back to Figma illustrations in tests and on desktop.

5. **Empty-stop semantics** — Stopping before speech returns `TalkListenResult.empty`, not demo sample text.

## Getting started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.12+)
- Android Studio / Xcode for device builds
- **Physical device recommended** for real speech recognition and 3D avatar

### Run locally

```bash
flutter pub get
flutter run
```

Run on a connected device:

```bash
flutter devices
flutter run --device-id <device-id>
```

### Run tests (matches CI)

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos --fatal-warnings
flutter test test/architecture/
flutter test --exclude-tags store-blocker
flutter test --tags golden-path
flutter test test/widget_test.dart --name "Tap listen"
flutter build apk --debug
```

### Merge protection (5 CI checks)

Pull requests to `main` run six CI jobs. The **PR merge gate** job fails unless all **5** core checks pass:

1. **Coding standards** — `dart format`, `flutter analyze`, `pubspec.lock` freshness  
2. **Architecture checks** — feature/service layer guardrails  
3. **Tests** — unit/widget tests (excluding `store-blocker`), golden-path tests, listen widget smoke test  
4. **Build Android** — debug APK build  
5. **iOS checks** — SwiftLint + debug iOS build (no codesign)

> Cloudflare Workers deploy checks and the PR template checklist are informational — they do not satisfy the merge gate.

To enforce this on GitHub (block merge when the gate is red), run once with admin access:

```bash
chmod +x scripts/setup-branch-protection.sh
./scripts/setup-branch-protection.sh
```

Requires [GitHub CLI](https://cli.github.com/) (`gh auth login`). Use `--dry-run` to preview the ruleset.

### Configure backend URLs (optional)

When remote microservices are available:

```bash
flutter run \
  --dart-define=HOME_SERVICE_URL=https://api.example.com/home \
  --dart-define=TRANSLATE_SERVICE_URL=https://api.example.com/translate
```

## License

See [LICENSE](LICENSE).
