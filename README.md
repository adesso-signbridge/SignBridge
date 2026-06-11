# SignBridge

SignBridge is a mobile accessibility app that helps **deaf** and **mute (non-verbal)** people communicate in everyday life. Using the phone, they can **hear** what others say and **reply** back — without needing to speak or read lips.

Built by [adesso](https://www.adesso.de/).

### Who it is for

| User need | How SignBridge helps |
|-----------|----------------------|
| **Deaf / hard of hearing** | Others speak into the app → SignBridge shows sign language (or text) so the user can *hear* and understand the conversation. |
| **Mute / non-verbal** | The user signs or selects phrases in the app → SignBridge speaks the message out loud so they can *reply* and be understood. |

SignBridge removes the communication barrier between spoken language and sign language, so deaf and mute users can take part in conversations at shops, hospitals, work, and home.

## What the app will do

SignBridge provides two core translation modes:

| Mode | Direction | Description |
|------|-----------|-------------|
| **Hear for me** | Voice → Sign | Someone speaks into the phone; the app converts speech into sign language so a deaf user can *hear* and understand. |
| **Speak for me** | Sign → Voice | The user signs or taps a phrase; the app converts it into spoken words so a mute user can *reply* and be heard. |

The app is organized around five main areas:

- **Home** — Entry point with action cards (Hear for me / Speak for me), language selection, and quick phrases for common situations (e.g. greetings, asking for help).
- **Translate** — Live translation between voice and sign.
- **Phrases** — Saved and frequently used phrases for faster communication.
- **SOS** — Emergency communication tools for urgent situations.
- **Settings** — App preferences, language, and accessibility options.

> **Current status:** The home screen, splash flow, and tab navigation are implemented. Translate, Phrases, SOS, and Settings screens are scaffolded and backed by local service adapters until backend microservices are connected.

## Technology stack

| Layer | Technology |
|-------|------------|
| Framework | [Flutter](https://flutter.dev/) |
| Language | Dart 3.12+ |
| UI | Material Design, custom Figma-based theme |
| Assets | PNG icons, SVG logos (`flutter_svg`) |
| Typography | Klavika Bold (brand font) |
| Platforms | Android, iOS (scaffold also includes web, macOS, Linux, Windows) |
| Testing | `flutter_test` widget tests |

## Architecture

The app follows a **feature-first layout** with a **microservice-oriented client architecture**. Each domain (home, translate, phrases, SOS, settings, splash) is an independent module that can talk to its own backend service when available.

```
lib/
├── main.dart                         # Bootstrap ServiceLocator, run app
├── app/                              # Root MaterialApp
├── core/
│   ├── di/service_locator.dart       # Dependency injection registry
│   ├── network/microservice_client.dart  # HTTP client for remote services
│   ├── services/microservice.dart    # Shared service contract
│   └── theme/                        # Colors, typography, spacing
├── features/
│   ├── splash/presentation/          # Splash screen
│   ├── home/presentation/            # Home screen UI
│   └── shared/presentation/          # Shared tab placeholders
├── services/
│   ├── home/                         # HomeService + LocalHomeService
│   ├── translate/                    # TranslateService + LocalTranslateService
│   ├── phrases/                      # PhrasesService + LocalPhrasesService
│   ├── sos/                          # SosService + LocalSosService
│   ├── settings/                     # SettingsService + LocalSettingsService
│   └── splash/                       # SplashService + LocalSplashService
└── shell/main_shell.dart             # Bottom tab bar + IndexedStack
```

### Key design decisions

1. **Service interfaces + adapters** — Each feature depends on an abstract service (e.g. `HomeService`). Local implementations provide mock/static data today; remote implementations can replace them without changing the UI.

2. **ServiceLocator** — A lightweight DI container wires all services at startup via `ServiceLocator.bootstrap()`.

3. **Independent microservice endpoints** — `MicroserviceClient` and `MicroserviceEndpoints` are prepared for per-service backend URLs (configurable via `--dart-define`).

4. **Shell navigation** — `MainShell` uses an `IndexedStack` to preserve tab state across the five bottom tabs.

### App flow

```
Native launch screen → Dart SplashScreen (2s) → MainShell (5 tabs)
```

## Getting started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.12+)
- Android Studio / Xcode for device simulators

### Run locally

```bash
flutter pub get
flutter run
```

### Run tests

```bash
flutter test
```

### Configure backend URLs (optional)

When remote microservices are available, pass service URLs at build time:

```bash
flutter run \
  --dart-define=HOME_SERVICE_URL=https://api.example.com/home \
  --dart-define=TRANSLATE_SERVICE_URL=https://api.example.com/translate
```

## License

See [LICENSE](LICENSE).
