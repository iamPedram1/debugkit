# Contributing to DebugKit

## Project Vision
DebugKit aims to be the standard in-app observability layer for Flutter. It should be lightweight, secure, and easy to integrate.

## Architecture Overview
- **Core**: Contains the models, store, and controller.
- **UI**: Contains the overlay button, console screen, and widgets.
- **Utils**: Contains sanitization, filtering, and export logic.
- **Adapters**: Future home for Dio, Riverpod, and other integrations.

## Folder Structure
```
lib/
  debug_kit.dart            # Public API
  src/
    core/                   # Logic and state
      controller/
      models/
      store/
      adapters/             # Adapter contracts
    ui/                     # Presentation
      overlay/              # Floating button logic
      screens/              # Main console UI
      widgets/              # UI components
    utils/                  # Pure utilities
      sanitizer/            # Security logic
      export/               # Exporting logic
      filtering/            # Searching logic
```

## Coding Style
- Follow official Flutter/Dart lint rules.
- Prefer `ChangeNotifier` for simple state management.
- Keep UI components small and focused.
- Ensure all logs are sanitized before storage.

## Security & Sanitization Rules
- NEVER store raw secrets.
- Use `DebugLogSanitizer` for all incoming strings.
- Masking: Show first/last few characters for verification.
- Redaction: Fully hide extremely sensitive data like private keys.

## Testing Requirements
- Every new core feature must have unit tests.
- Sanitization logic must be rigorously tested with various patterns.
- Ensure bounded store behavior (no memory leaks).

## Monorepo Management

This project uses [Melos](https://melos.invertase.dev/) for monorepo management.

- **Bootstrap**: `melos bootstrap` (or `flutter pub get` in each package)
- **Analyze**: `melos run analyze`
- **Test**: `melos run test`
- **Format**: `melos run format`

## PR Checklist
- [ ] Tests pass (`melos run test`)
- [ ] Analysis passes (`melos run analyze`)
- [ ] Formatting is correct (`melos run format`)
- [ ] README is updated if necessary
- [ ] No new dependencies introduced without discussion
