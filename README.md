# DebugKit Monorepo

A mobile-first, in-app DevTools cockpit for Flutter apps.

DebugKit provides a searchable, filterable log viewer directly inside your app. It helps developers inspect logs, verify network calls, and debug state transitions without needing to attach a debugger or tail server logs.

## Monorepo Overview

This repository is managed as a monorepo using [Melos](https://melos.invertase.dev/). It contains the core DebugKit package and various adapter packages for popular Flutter libraries.

### Packages

| Package | Version | Description |
| :--- | :--- | :--- |
| [**debug_kit**](packages/debug_kit) | 0.5.1 | Core logging engine, UI console, and Error Digest. |
| [**debug_kit_dio**](packages/debug_kit_dio) | 0.2.2 | Dio interceptor for network observability. |
| [**debug_kit_go_router**](packages/debug_kit_go_router) | 0.2.2 | GoRouter observer for navigation logs. |
| [**debug_kit_riverpod**](packages/debug_kit_riverpod) | 0.2.2 | Riverpod observer for state changes. |

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
- **Phase 3**: Error Digest / Error Intelligence. [COMPLETED]
- **Phase 4**: Enhanced Diagnosis (Global error capture, Network summary).
- **Phase 5**: Advanced Features (AI Prompt Builder, Reproduction Sessions).

## Documentation

- [Contributing Guidelines](CONTRIBUTING.md)
- [Engineering Constitution](AGENTS.md)
- [Support](SUPPORT.md)
- [Security Policy](SECURITY.md)
- [Core Package Usage](packages/debug_kit/README.md)
- [Release Process](docs/RELEASE.md)

## Community Support

Issues and feature requests are handled through GitHub issue forms so reports
stay structured and easy to triage. Please choose the most specific template
available when opening a new issue.

## License

MIT
