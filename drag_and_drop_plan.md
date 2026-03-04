# Drag & Drop Implementation Plan for Fima

## Context
Fima is a dual-panel file manager. Users need drag & drop to move files between panels, drop onto folders, and interoperate with OS file managers (Finder, Nautilus, Explorer). Currently there is no DnD code — all file operations use keyboard shortcuts (F5/F6 copy/move, Ctrl+C/V clipboard).

## Library
`super_drag_and_drop: ^0.9.1` — cross-platform (Linux/macOS/Windows), supports native file URIs, nested drop regions.

## Files to Create

### 1. `lib/presentation/providers/drag_state_provider.dart`
Riverpod provider tracking active drag state across both panels:
- `sourcePanelId` — which panel started the drag (null = external)
- `draggedPaths` — list of paths being dragged
- `hoveredDropTargetPath` — path of folder being hovered (for highlight)
- Methods: `startInternalDrag()`, `setHoveredTarget()`, `endDrag()`

### 2. `lib/presentation/widgets/panel/draggable_file_item.dart`
Widget wrapping each file row with `DragItemWidget` + `DraggableWidget`:
- Skips parent entry (`..`) — not draggable
- Resolves drag paths: if item is in `selectedItems` set → drag all selected; otherwise drag single item
- Provides `Formats.fileUri` for local paths (enables external drag to OS file managers)
- Provides `Formats.plainText` fallback (path list)
- SSH paths: only provide plainText (no local file URI)
- Uses `DragItem.localData` to pass paths internally (avoids async deserialization)
- `dragBuilder` creates a compact card showing count badge + first filename + icon

### 3. `lib/presentation/widgets/panel/drop_target_item.dart`
Two widgets:

**`DropTargetFolder`** — wraps each directory row with `DropRegion`:
- `onDropOver`: sets `hoveredDropTargetPath` in drag state provider, returns `DropOperation.move` (internal) or `.copy` (external)
- `onDropLeave`: clears hover
- `onPerformDrop`: delegates to shared `_handleDrop` callback
- Visual: wraps child with conditional accent-colored border when hovered

**`DropTargetPanel`** — wraps the entire `ListView` area with `DropRegion`:
- `hitTestBehavior: translucent` so folder-level targets intercept first
- Drop on panel background → move/copy to panel's `currentPath`
- Same callback pattern as folder target

## Files to Modify

### 4. `pubspec.yaml`
Add `super_drag_and_drop: ^0.9.1` under dependencies.

### 5. `lib/presentation/widgets/panel/file_panel.dart` (main changes)
**Imports**: Add new widgets and `drag_state_provider`.

**Wrap ListView area** (line 524, the `Expanded` block) with `DropTargetPanel`:
```
DropTargetPanel(
  panelId: widget.panelId,
  currentPath: panelState.currentPath,
  onDrop: _handleDrop,
  child: /* existing GestureDetector + ListView */,
)
```

**Wrap each item** in `itemBuilder` (line 560):
- Wrap the existing `GestureDetector` row with `DraggableFileItem`
- For directory items (non-parent): additionally wrap with `DropTargetFolder`

**Add `_handleDrop` method** to `_FilePanelState`:
```
Future<void> _handleDrop(PerformDropEvent event, String targetPath)
```
Two paths:
1. **Internal drag** (`dragState.sourcePanelId != null`):
   - Get `draggedPaths` from drag state (set via `localData`)
   - Guard: skip if dropping on self or same parent folder
   - Call `repository.moveItems(paths, targetPath, token)`
   - Listen to stream for progress (update panel operation progress)
   - On done: refresh both panels using `loadPath(currentPath, preserveFocusedIndex: true)`
   - Clear selection on source panel after move
2. **External drag** (`sourcePanelId == null`):
   - Read `Formats.fileUri` from each `event.session.items`
   - Call `repository.copyItem(sourcePath, joinedTargetPath)` for each file
   - Refresh current panel

**Add drop target highlight** in item rendering:
- Watch `dragStateProvider`
- When `hoveredDropTargetPath == item.path` → add accent border to the folder row's `BoxDecoration`

### 6. `lib/domain/entity/app_theme.dart` (optional)
Add `dropTargetHighlightColor` field. Alternatively, reuse `accentColor` for the highlight border (simpler, consistent with focused item styling). **Recommendation**: reuse `accentColor` — no theme changes needed.

## Operation Semantics

| Scenario | Operation |
|----------|-----------|
| Internal DnD (within/between panels) | **Move** |
| External drop INTO fima | **Copy** |
| External drag FROM fima | OS decides (we provide `fileUri`) |

## Edge Cases

| Case | Handling |
|------|----------|
| Drag `..` parent entry | Not draggable (skip in DraggableFileItem) |
| Drop on self / same parent | Guard check → abort silently |
| Drop folder into its own child | Repository throws IO error → catch and show toast |
| Drag during rename mode | Return null from `dragItemProvider` when `editingPath` is set |
| SSH paths dragged externally | Only plainText format (no fileUri) — OS gets path text, not file |
| Zip archive paths | Not draggable externally (no local file representation) |
| Empty panel drop | Uses panel's `currentPath` as target |

## Implementation Order

1. Add `super_drag_and_drop` to `pubspec.yaml`, run `flutter pub get`
2. Create `drag_state_provider.dart`
3. Create `draggable_file_item.dart`
4. Create `drop_target_item.dart` (both `DropTargetFolder` and `DropTargetPanel`)
5. Modify `file_panel.dart`:
   - Add imports
   - Wrap ListView with `DropTargetPanel`
   - Wrap items with `DraggableFileItem` and `DropTargetFolder`
   - Add `_handleDrop` method
   - Add hover highlight in item decoration
6. Test internal single-item drag between panels
7. Test internal multi-item drag (select with Space, then drag)
8. Test dropping onto folders within same panel
9. Test external drop from OS file manager into fima
10. Test external drag from fima to OS file manager
11. Test edge cases (parent entry, SSH paths, self-drop)

## Verification
- Run `flutter analyze` — no lint errors
- Run on Linux: test DnD with Nautilus/Dolphin
- Run on macOS: test DnD with Finder
- Run on Windows: test DnD with Explorer
- Verify: drag single file to folder in opposite panel → file moves
- Verify: select 3 files, drag group to folder → all 3 move
- Verify: drag from Finder into fima → files copied
- Verify: drag from fima to Finder → files available in Finder
- Verify: both panels refresh correctly after drop
