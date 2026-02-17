# AGENTS.md - Fima AI Development Guide

This document provides guidelines and commands for agents working on the Fima project (two-panel file manager).

## Build, Lint, and Test Commands

### Flutter Commands
```bash
# Run the application
flutter run

# Build for Linux desktop
flutter build linux

# Analyze code for errors and warnings
flutter analyze

# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Run tests with verbose output
flutter test -v

# Run tests matching a pattern
flutter test --name "App starts"
```

### Common Development Commands
```bash
# Get dependencies
flutter pub get

# Format code
dart format .

# Run with specific device
flutter run -d linux
```

---

## Code Style Guidelines

### General Principles
- Follow standard Flutter/Dart conventions
- Keep code concise and readable
- No unnecessary comments (unless explaining complex logic)
- Use meaningful variable and function names

### Imports
- Use package imports: `import 'package:fima/...'`
- Order imports alphabetically within groups
- Separate groups with blank lines:
  1. Dart SDK imports
  2. Flutter/framework imports
  3. Third-party packages
  4. Project imports (package:fima/...)

Example:
```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
```

### Naming Conventions

#### Classes and Types
- Use PascalCase: `class FilePanel`, `class PanelState`
- Use singular nouns: `FileItem`, not `Files`

#### Variables and Functions
- Use camelCase: `final selectedPaths`, `void loadPath()`
- Private members start with underscore: `_hoveredDirectory`
- Boolean variables should be predicates: `isSelected`, `hasItems`

#### Constants
- Use camelCase for const values: `const itemHeight = 24.0`
- Use PascalCase for enum values: `SortColumn.name`

### Types and Type Safety

#### Prefer Explicit Types
- Always specify return types for functions
- Use type inference for local variables when clear
- Avoid `dynamic` unless necessary

```dart
// Good
final List<String> selectedPaths = [];
Future<void> loadPath(String path) async { }

// Acceptable
final items = <FileSystemItem>[];
```

#### Null Safety
- Use nullable types sparingly: `String?`
- Use null-aware operators: `?.`, `??`, `?[]`
- Avoid `!` operator; handle null cases explicitly

### Widgets and UI

#### Building UI
- Use `const` constructors where possible
- Extract repeated UI into separate widget methods
- Keep build methods focused and readable

#### State Management
- Use Riverpod providers (`StateNotifierProvider`, `Provider`)
- Follow the pattern: `providerNameProvider` for providers
- Keep business logic in controllers (StateNotifiers)

Example:
```dart
final panelStateProvider = StateNotifierProvider.family<PanelController, PanelState, String>(
  (ref, panelId) => PanelController(ref, panelId),
);
```

### Error Handling

#### Use try-catch for Operations
```dart
try {
  await _repository.deleteItem(path);
} catch (e) {
  debugPrint('Error deleting $path: $e');
}
```

#### Use debugPrint for Logging
- Use `debugPrint()` for logging (not `print()`)
- Include context in error messages

#### File Operations
- Handle exceptions for file system operations
- Provide user feedback for failures

### Code Formatting

#### General Rules
- Use 2 spaces for indentation
- Maximum line length: 80-100 characters (soft limit)
- Use trailing commas for better diffs
- Opening braces on same line

#### Example
```dart
Widget _buildColumnHeader(
  String title,
  SortColumn column,
  PanelState state,
  VoidCallback onTap,
) {
  final theme = Theme.of(context);
  final isActive = state.sortColumn == column;

  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
        ],
      ),
    ),
  );
}
```

### Flutter Development Rules & Workflow

You are assisting with a Flutter project. I am running the app in a separate terminal using `flutter run`.

#### Hot Reload

When I ask you to trigger a Hot Reload (after I've completed all code changes), execute this command:

```bash
pgrep -f "flutter_tools.snapshot run" | xargs kill -USR1
```

For Hot Restart (full restart), use:

```bash
pgrep -f "flutter_tools.snapshot run" | xargs kill -USR2
```

**Note:** This approach is more reliable than `pkill -USR1 -f "flutter run"` as it targets the specific Flutter incremental compiler process.

### Testing

#### Widget Tests
- Use `flutter_test` package
- Use `WidgetTester` for interactions
- Wrap widget in `ProviderScope` for Riverpod

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FimaApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
```

### File Organization

```
lib/
├── domain/           # Business logic layer
│   ├── entity/      # Data models
│   └── repository/  # Repository interfaces
├── infrastructure/  # Implementation details
│   ├── repository/  # Repository implementations
│   └── service/     # External services
└── presentation/    # UI layer
    ├── providers/   # Riverpod providers
    └── widgets/    # UI components
```

### Deprecation Warnings

- Use `.withValues(alpha: x)` instead of deprecated `.withOpacity(x)`
- Keep dependencies up to date

### Best Practices

1. **Immutability**: Prefer immutable data classes where possible
2. **Single Responsibility**: Each class/method should do one thing
3. **Early Returns**: Return early to avoid nested conditionals
4. **Avoid Magic Numbers**: Use named constants
5. **Leverage IDE**: Use Flutter analyzer and IDE hints

---

## Project Context

- **App Name**: Fima - Two-panel file manager
- **Framework**: Flutter Desktop (Linux, Windows, macOS)
- **State Management**: Riverpod
- **Architecture**: Clean Architecture (domain/infrastructure/presentation)
- **Lints**: flutter_lints (enabled via analysis_options.yaml)
