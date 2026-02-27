# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run the app
flutter run -d linux     # Run on specific device
flutter build linux      # Build for Linux desktop
flutter analyze          # Lint / static analysis
dart format .            # Format code
flutter test             # Run all tests
flutter test test/widget_test.dart  # Run a single test file
flutter test --name "App starts"    # Run tests matching a pattern
```

### Hot Reload (while app is running in a separate terminal)

```bash
# Hot reload
pgrep -f "flutter_tools.snapshot run" | xargs kill -USR1
# Hot restart
pgrep -f "flutter_tools.snapshot run" | xargs kill -USR2
```

## Architecture

Fima follows Clean Architecture across three layers:

```
lib/
├── domain/           # Pure business logic, no Flutter dependencies
│   ├── entity/       # Immutable data models (PanelState, FileSystemItem, UserSettings, …)
│   └── repository/   # Abstract repository interfaces (FileSystemRepository)
├── infrastructure/   # Concrete implementations
│   ├── repository/   # LocalFileSystemRepository, SshFileSystemRepository,
│   │                 #   ZipFileSystemRepository, CompoundFileSystemRepository
│   └── service/      # SettingsService, ThemeService, keyboard utils, etc.
└── presentation/
    ├── providers/    # Riverpod providers + StateNotifier controllers
    └── widgets/      # UI widgets
```

### FileSystem routing

`CompoundFileSystemRepository` is the single `FileSystemRepository` exposed to the app. It inspects the path prefix and routes to the correct backend:

| Path prefix | Repository |
|-------------|-----------|
| `ssh://`    | `SshFileSystemRepository` |
| contains `.zip` | `ZipFileSystemRepository` |
| everything else | `LocalFileSystemRepository` |

SSH paths use the scheme `ssh://<connectionId>/remote/path`.

### State management

All state is managed with **Riverpod**. The key provider is:

```dart
final panelStateProvider =
    StateNotifierProvider.family<PanelController, PanelState, String>(…);
```

The two panel IDs are `'left'` and `'right'`. `PanelController` is the central controller for navigation, selection, sorting, renaming, file operations, and archive handling.

`userSettingsProvider` (`SettingsController`) owns all persistent settings. Every mutating method calls `save()` automatically, so settings are always persisted.

`overlayProvider` controls full-screen overlays (built-in terminal, settings dialog). When an overlay is active, `KeyboardHandler` blocks most global shortcuts.

### Keyboard actions

`KeyboardHandler` (wraps the entire widget tree) intercepts all key events and resolves them against the user's key map via `SettingsController.findActionByShortcut()`. Each action has a string ID (e.g., `'moveUp'`, `'enterDirectory'`, `'copyToClipboard'`). All IDs and default shortcuts are defined in `lib/domain/entity/key_map_action.dart`.

Plain printable characters (no modifiers) feed the **quick-filter** instead of triggering actions.

### App startup sequence

`main.dart` → loads `UserSettings` → loads theme → renders `KeyboardHandler(MainScreen())`. `MainScreen` initialises both `PanelController`s with their saved paths.

## Code style

- Use `package:fima/…` imports (not relative).
- Import order: Dart SDK → Flutter/framework → third-party → `package:fima/…`, each group blank-line separated.
- Use `.withValues(alpha: x)` — not the deprecated `.withOpacity(x)`.
- Use `debugPrint()` for logging, not `print()`.
- Use 2-space indentation and trailing commas.
- Avoid the `!` null-assertion operator; handle null cases explicitly.
