# GEMINI.md - Fima AI Development Guide

See [AGENTS.md](AGENTS.md) for full guidelines.

## Critical Build Requirement

The `file_icon` package uses non-constant `IconData` instances, which breaks Flutter's icon tree-shaking.
**Always include `--no-tree-shake-icons`** in every build and run command:

```bash
flutter run --no-tree-shake-icons
flutter build macos --no-tree-shake-icons
flutter build linux --no-tree-shake-icons
flutter build windows --no-tree-shake-icons
```

Omitting this flag will cause a build failure.
