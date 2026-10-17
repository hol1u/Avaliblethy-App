# Avaliblethy

Cross-platform LLM chat client (Android, iOS, macOS, Windows; web enabled for later) built with Flutter.
Stage 1 ships a working app against a mock provider plus an OpenAI-compatible remote provider and a CI pipeline.

## Requirements

- Flutter **3.47.7** (stable, Dart 3.13). The version is pinned in `.github/workflows/*.yml` and `.devcontainer/devcontainer.json`.

## Setup

```bash
cd app
flutter pub get
flutter run -d <device>      # macos | windows | chrome | an emulator / iPad / phone
```

Generated Drift code (`lib/data/database.g.dart`) is committed. After changing the schema in `lib/data/database.dart`:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Run in the browser (Codespaces)

The devcontainer installs the pinned Flutter SDK and forwards port 8080:

```bash
cd app
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0
```

Open the forwarded port 8080. History is persisted in the browser (IndexedDB/OPFS) via Drift's WASM SQLite
(`app/web/sqlite3.wasm` and `app/web/drift_worker.js`, matching the locked `sqlite3` / `drift` versions;
update them when upgrading those packages).

## Using the providers

Open **Settings** (drawer / sidebar) to pick the provider.

- **Mock** (default): streams a fake reply. Send `/long` (or `/code`) for a long markdown reply with code blocks, `/error` to simulate a failure.
- **Remote**: any OpenAI-compatible server, e.g. llama.cpp:
  ```bash
  llama-server -m model.gguf --port 8081
  ```
  Set Base URL `http://localhost:8081`, model name, and an optional API key. Requests go to `{baseUrl}/v1/chat/completions`
  with `stream: true` (a trailing `/v1` in the base URL is tolerated).
  On web the server must allow CORS.

Note: settings (including the API key) are stored in plain `shared_preferences`. Secure storage is out of scope for Stage 1.

## Architecture

```
app/lib/
  core/              theme, layout constants
  data/              Drift database (conversations, messages), repositories, settings storage
  providers/         ChatProvider interface, MockProvider, RemoteProvider, SSE parser
  features/chat/     chat screen, controller (streaming state), widgets
  features/settings/ settings screen
  app_providers.dart Riverpod wiring (DB, settings, active ChatProvider)
```

- `ChatProvider.streamChat(ChatRequest)` returns `Stream<ChatChunk>`; cancelling the subscription aborts generation
  (for `RemoteProvider` it cancels the HTTP request). The UI's Stop button does exactly that and keeps the partial reply.
- `ChatController` persists the user message, streams the reply into in-memory state, and stores the assistant message when
  the stream ends, is stopped, or fails.
- The chat pane is a reversed list so it stays pinned to the newest message while streaming.
- Layout: width >= 840 shows a permanent conversation sidebar, otherwise a drawer. Enter sends, Shift+Enter inserts a newline.

## Tests

```bash
cd app
flutter analyze
flutter test
```

## Builds

| Platform | Command (run in `app/`) | Host |
| --- | --- | --- |
| Android | `flutter build apk --release` | any |
| Windows | `flutter build windows --release` | Windows |
| macOS | `flutter build macos --release` (unsigned) | macOS |
| iOS | `flutter build ios --release --no-codesign` | macOS |
| Web | `flutter build web` | any |

`.github/workflows/ci.yml` runs pub get, analyze and test on every push/PR. `.github/workflows/build.yml` builds all four
platforms in a matrix and uploads artifacts (`avaliblethy-<platform>`). Release signing is out of scope.
