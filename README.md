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
Tap Listen → mic permission → speech-to-text (device)
           → live caption (top bubble)
           → ASL/ISL gloss (blue chip)
           → native 3D avatar (same sign as chip)
           → Heard → Signing (cycles gloss sequence)
Stop       → saved transcript or "No speech detected"
Clear      → return to idle
```

| Spoken language | Sign system |
|-----------------|-------------|
| English (ENG)   | ASL         |
| Hindi, Tamil, Malayalam | ISL |

**Permissions:** microphone and speech recognition (iOS `Info.plist`, Android `RECORD_AUDIO`).

**Simulator / CI:** uses a local mock speech pipeline (`LocalTranslateService(forceMockListening: true)` in tests).

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

## Architecture

The app follows a **feature-first layout** with a **microservice-oriented client architecture**. Each domain (home, translate, phrases, SOS, settings, splash) is an independent module that can talk to its own backend service when available.

```
lib/
├── main.dart                         # Bootstrap ServiceLocator, run app
├── app/                              # Root MaterialApp
├── core/
│   ├── di/service_locator.dart       # Dependency injection registry
│   ├── platform/                     # Mic permission, sign avatar channel
│   ├── network/microservice_client.dart
│   ├── services/microservice.dart
│   └── theme/
├── features/
│   ├── splash/presentation/
│   ├── home/presentation/            # Talk screen + session UI
│   └── shared/presentation/
├── services/
│   ├── home/                         # HomeService + localized UI copy
│   ├── translate/                    # STT, ASL/ISL catalog, listen stream
│   ├── phrases/, sos/, settings/, splash/
└── shell/main_shell.dart
```

### Key design decisions

1. **Service interfaces + adapters** — UI depends on abstractions (`TranslateService`, `HomeService`). Local implementations ship today; remote adapters swap in without UI changes.

2. **Session generation tokens** — `HomeScreen` uses monotonic generation counters so async listen/stop/clear races cannot apply stale UI updates.

3. **Native avatar bridge** — `SignAvatarChannel` + platform views keep 3D rendering on the platform thread; Flutter falls back to Figma illustrations in tests and on desktop.

4. **Empty-stop semantics** — Stopping before speech returns `TalkListenResult.empty`, not demo sample text.

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

### Run tests (matches CI)

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos --fatal-warnings
flutter test --exclude-tags store-blocker
```

### Configure backend URLs (optional)

When remote microservices are available:

```bash
flutter run \
  --dart-define=HOME_SERVICE_URL=https://api.example.com/home \
  --dart-define=TRANSLATE_SERVICE_URL=https://api.example.com/translate
```

## License

See [LICENSE](LICENSE).
