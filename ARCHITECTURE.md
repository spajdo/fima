# Fima Architecture & Module Guide

Fima follows **Clean Architecture** with three strict layers (`domain`, `infrastructure`, `presentation`) and single-responsibility modules. Read this guide before adding new features or refactoring existing ones.

---

## 1. Layer Boundaries & Dependency Rule

```text
presentation  ──▶  domain  ◀──  infrastructure
      │                              ▲
      └──────── (via Riverpod) ──────┘
```

1. **`domain/`** — Pure Dart/business rules, immutable entities, repository interfaces, and pure utility functions.
   - **Allowed imports**: Dart SDK, `path`, and `package:fima/domain/...`.
   - **Forbidden**: `flutter/material.dart` widgets, `flutter_riverpod`, OS `Process` calls, or imports from `infrastructure/` / `presentation/`.
2. **`infrastructure/`** — Concrete implementations of `domain` repositories and external/OS/filesystem/SSH/isolate services.
   - **Allowed imports**: `domain/`, third-party packages (`dartssh2`, `archive`, `image`, etc.), `dart:io`, `dart:isolate`.
   - **Forbidden**: UI widgets, dialogs, `BuildContext`, or `presentation/` providers.
3. **`presentation/`** — Riverpod state notifiers/providers and Flutter UI widgets.
   - **Rule**: Keep I/O, archiving, process launching, checksums, and diff computation in `infrastructure/service/`; keep widgets thin and focused on rendering and user interaction.

---

## 2. Directory & Module Map

### `lib/domain/`
- **`entity/`** — Immutable data models and action definitions (`app_action.dart`, `app_theme.dart`, `bookmark.dart`, `default_themes.dart`, `desktop_application.dart`, `file_operation.dart`, `file_system_item.dart`, `key_map_action.dart`, `panel_operation_progress.dart`, `panel_state.dart`, `panel_tab.dart`, `path_index_entry.dart`, `remote_connection.dart`, `user_settings.dart`, `workspace.dart`).
- **`repository/`**
  - `file_system_repository.dart`: Abstract contract for local, SSH, and ZIP filesystem operations.
- **`utils/`** — Pure, unit-testable domain helpers:
  - `fima_path.dart`: Canonical scheme detection (`ssh://`, ZIP paths) and Zip-Slip / self-copy path-containment guards.
  - `file_item_sorter.dart`: Sorting (`..` first, folders before files, dynamic folder sizes) and quick-filter prefix matching.
  - `file_size_formatter.dart`: Shared human-readable byte formatting.

### `lib/infrastructure/`
- **`repository/`**
  - `local_file_system_repository.dart`: Local filesystem operations with symlink and self/descendant safety checks.
  - `ssh_file_system_repository.dart`: SFTP/SSH connection handling, directory listing, streaming transfer/edit support.
  - `zip_file_system_repository.dart`: Virtual browsing and read-only extraction inside `.zip` archives with Zip-Slip protection.
  - `compound_file_system_repository.dart`: Routes paths cleanly between local, SSH, and ZIP repositories and coordinates cross-backend recursive transfers.
- **`service/`**
  - `archive_service.dart`: Background isolate ZIP compression and extraction (with Zip-Slip guard).
  - `desktop_integration_service.dart`: Cross-platform OS launches (open file, terminal, file manager, reveal in finder/explorer, open with app).
  - `remote_session_manager.dart`: Reusable SSH auto-connect / remembered-password orchestration used by tab switching and dialogs.
  - `remote_file_edit_service.dart`: SSH remote-edit temporary mirror, change watcher, auto-upload, and live log tailing.
  - `file_diff_service.dart`: Background LCS diff calculation and hunk indexing.
  - `item_metadata_service.dart`: Facade coordinating `metadata/` services:
    - `metadata/item_metadata_models.dart`: `ItemMetadata`, `FileChecksums`, `DirectoryStatsHandle`.
    - `metadata/file_kind_descriptor.dart`: File extension/type descriptions.
    - `metadata/posix_permissions_service.dart`: `rwx`/`octal` formatting and local/SFTP `chmod`.
    - `metadata/directory_stats_calculator.dart`: Isolate recursive directory byte/item scanner and single-folder size calculation.
    - `metadata/file_checksum_service.dart`: Streaming MD5 + SHA-256 isolate calculator.
  - `application_service.dart`, `macos_application_service.dart`, `linux_application_service.dart`, `windows_application_service.dart`: Platform installed-app discovery.
  - `global_hotkey_service.dart`, `keyboard_utils.dart`, `secure_password_service.dart`, `settings_service.dart`, `ssh_file_tail_service.dart`, `system_clipboard_service.dart`, `theme_service.dart`, `window_toggle_service.dart`: Platform/storage utilities.

### `lib/presentation/`
- **`providers/`**
  - `app_action_dispatcher.dart`: **Single source of truth** for executing user actions across keyboard shortcuts, Omni palette (`>`), and context menus. Captures Riverpod notifiers before opening popups so callbacks remain safe after callers dispose.
  - `action_provider.dart`: Builds `AppAction` entries for Omni (`>`) and delegates execution to `AppActionDispatcher`.
  - `file_system_provider.dart`: `PanelController` (`StateNotifier` per tab with `_loadGeneration` guard against stale async responses) and service/repository providers.
  - `panel_tabs_provider.dart`: Per-panel tab lifecycle, workspace loading, and SSH auto-reconnect.
  - `clipboard_actions.dart`, `internal_clipboard_provider.dart`, `operation_status_provider.dart`: Cross-panel copy/cut/paste, drag-drop operations, and toast error feedback.
  - `panel_feature_actions.dart`, `focus_provider.dart`, `settings_provider.dart`, `theme_provider.dart`, `overlay_provider.dart`, `drag_state_provider.dart`, `global_hotkey_provider.dart`: Feature actions & UI state.
- **`widgets/`**
  - Top-level shell: `main_screen.dart`, `keyboard_handler.dart`, `bottom_status_bar.dart`, `window_manager_initializer.dart`.
  - **`panel/`**: `file_panel.dart`, `panel_tab_bar.dart`, `panel_overlay.dart`, `built_in_terminal.dart`, `draggable_file_item.dart`, `drop_target_item.dart`, `rename_field.dart`, `file_context_menu.dart`.
    - `panel/widgets/`: `panel_path_bar.dart` (breadcrumbs, inline path bar editor, SSH header), `panel_column_header.dart` (column sizing + sortable headers), `panel_file_row.dart`, `panel_footer_bars.dart` (quick filter & progress bars), `panel_drop_handler.dart`.
    - `panel/context_menu/`: `context_menu_spec.dart` (pure declarative menu entries with shared sections) and `context_menu_executor.dart` (delegates execution to `AppActionDispatcher` & controllers).
  - **`popups/`**: Modals & settings dialogs (`settings_dialog.dart`, `key_map_tab.dart`, `about_dialog.dart`, `walkthrough_dialog.dart`, `shortcuts_dialog.dart`, `file_preview_dialog.dart`, `image_preview_dialog.dart`, `connect_server_dialog.dart`, `application_picker_dialog.dart`, `permissions_dialog.dart`, `delete_confirmation_dialog.dart`, `text_input_dialog.dart`, `base_dialog.dart`, `shortcut_recorder.dart`).
    - `popups/info/`: `item_info_dialog.dart` split into `info_section_card.dart`, `info_summary_header.dart`, `info_general_section.dart`, `info_checksums_section.dart`, `info_permissions_section.dart`.
    - `popups/omni/`: `omni_dialog.dart` split into `omni_models.dart`, `omni_result_tiles.dart`, `omni_item_actions.dart`.
    - `popups/diff/`: `file_diff_dialog.dart` split into `diff_toolbar.dart`, `diff_row_tile.dart`.

---

## 3. Rules for Future Changes (Anti-Duplication & Safety)

| When you need to... | Put it here | Never do this |
|---|---|---|
| Add or change a keyboard / palette / menu action | Define in `KeyMapActionDefs`, implement once in `AppActionDispatcher`, reference from `ActionGenerator` / `ContextMenuSpec` | Copy-paste dialog/terminal/archive logic across `KeyboardHandler`, `ActionGenerator`, and `FileContextMenu` |
| Parse, join, or validate paths (`local`, `ssh://`, `.zip`) | `FimaPath` (`domain/utils/fima_path.dart`) | Ad-hoc string splitting or unvalidated `p.join` inside UI widgets |
| Sort items, format sizes, parse Omni mode prefixes | `domain/utils/` or `popups/omni/omni_models.dart` | Duplicate formatters or sorting helpers inside multiple widgets |
| Run external processes, archives, hashing, SSH tails | `infrastructure/service/` | Run `Process.run` or `Isolate.run` directly inside a widget `State` |
| Trigger a dialog whose `.then()` mutates state after close | Capture required `ref.read(...)` notifiers *before* `Navigator.pop()` / `showDialog()` | Call `ref.read(...)` on a disposed dialog `ConsumerState` |
| Perform async work scoped to a specific tab (`loadPath`, SSH load) | Bind explicitly to `tabId` and check generation/disposal (`_loadGeneration`, `mounted`) | Read dynamic `activeTabId` *after* an `await` (risk of hijacking another panel/tab) |
| Build complex panels or dialogs (> ~350 lines) | Extract focused widgets into feature subfolders (`widgets/`, `info/`, `omni/`, `diff/`, `context_menu/`) | Grow monolithic 900+ line widget files |
