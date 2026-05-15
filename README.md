# DebugKit Monorepo

A mobile-first, in-app DevTools cockpit for Flutter apps.

DebugKit provides a searchable, filterable log viewer directly inside your app. It helps developers inspect logs, verify network calls, and debug state transitions without needing to attach a debugger or tail server logs.

## Screenshots

*(TODO: Add actual screenshots before pub.dev release)*

<div align="center">
  <img src="docs/assets/screenshots/overlay-button.png" width="200" alt="Overlay Button Placeholder">
  <img src="docs/assets/screenshots/console-all-logs.png" width="200" alt="Console Placeholder">
  <img src="docs/assets/screenshots/console-expanded-log.png" width="200" alt="Expanded Log Placeholder">
</div>

## Monorepo Overview

This repository is managed as a monorepo using [Melos](https://melos.invertase.dev/). It contains the core DebugKit package and various adapter packages for popular Flutter libraries.

### Packages

| Package | Version | Description |
| :--- | :--- | :--- |
| [**debug_kit**](packages/debug_kit) | 0.2.1 | Core logging engine and UI console. |
| [**debug_kit_dio**](packages/debug_kit_dio) | 0.1.0 | Dio interceptor for network observability. |
| [**debug_kit_go_router**](packages/debug_kit_go_router) | 0.1.0 | GoRouter observer for navigation logs. |
| [**debug_kit_riverpod**](packages/debug_kit_riverpod) | 0.1.0 | Riverpod observer for state changes. |

### Example App

A full demonstration of DebugKit and all its official adapters working together is available in the [`examples/debug_kit_example`](examples/debug_kit_example) directory. 
It showcases:
- Manual Logs & Sanitization
- Network Interceptors
- Navigation Observers
- State Observers

**Run the showcase:**

```bash
cd examples/debug_kit_example
flutter run
```

### Project Structure

```text
debugkit/
  ├── packages/
  │   ├── debug_kit/             # Core package
  │   ├── debug_kit_dio/         # Dio network adapter
  │   ├── debug_kit_go_router/   # GoRouter navigation adapter
  │   └── debug_kit_riverpod/    # Riverpod state observer adapter
  ├── examples/
  │   └── debug_kit_example/     # Demonstration app
  ├── docs/
  │   └── RELEASE.md             # Release checklist and process
  ├── melos.yaml                 # Monorepo configuration
  └── AGENTS.md                  # Engineering constitution
```

## Development

### Prerequisites

- Flutter SDK
- [Melos](https://melos.invertase.dev/) (`dart pub global activate melos`)

### Common Commands

| Command | Description |
| :--- | :--- |
| `melos bootstrap` | Initialize the workspace and link packages. |
| `melos run analyze` | Run flutter analyze across all packages. |
| `melos run test` | Run flutter test across all packages. |
| `melos run format` | Run dart format across all packages. |
| `melos run publish-dry-run` | Run pub publish dry-run in all publishable packages. |

## Roadmap

- **Phase 1**: Core MVP (Logging, Sanitization, Console UI). [COMPLETED]
- **Phase 2**: Essential Adapters (Dio, Riverpod, GoRouter). [COMPLETED]
- **Phase 3**: Enhanced Diagnosis (Error grouping, Network summary).
- **Phase 4**: Advanced Features (AI Prompt Builder, Reproduction Sessions).

## Documentation

- [Contributing Guidelines](CONTRIBUTING.md)
- [Engineering Constitution](AGENTS.md)
- [Core Package Usage](packages/debug_kit/README.md)
- [Release Process](docs/RELEASE.md)

## License

MIT
