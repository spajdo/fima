import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fima/domain/entity/app_action.dart';
import 'package:fima/domain/entity/key_map_action.dart';
import 'package:fima/presentation/providers/app_action_dispatcher.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/panel_tabs_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';

/// Generates Omni-panel executable [AppAction] entries based on keymap
/// definitions and the active panel's focused item context.
class ActionGenerator {
  final WidgetRef ref;
  final BuildContext context;

  ActionGenerator(this.context, this.ref);

  List<AppAction> generate() {
    final activePanelId = ref.read(focusProvider.notifier).getActivePanelId();
    final activeTabId = ref.read(panelTabsProvider(activePanelId)).activeTabId;
    final settingsNotifier = ref.read(userSettingsProvider.notifier);
    final panelState = ref.read(panelStateProvider(activeTabId));

    bool isZipFocused = false;
    if (panelState.focusedIndex >= 0 &&
        panelState.focusedIndex < panelState.items.length) {
      final focusedItem = panelState.items[panelState.focusedIndex];
      if (focusedItem.path.toLowerCase().endsWith('.zip') &&
          !focusedItem.isDirectory &&
          !focusedItem.isParentDetails) {
        isZipFocused = true;
      }
    }

    final actions = KeyMapActionDefs.omniPanelActions.map((action) {
      return AppAction(
        id: action.id,
        label: action.label,
        shortcut: settingsNotifier.getEffectiveShortcut(action.id),
        callback: () => AppActionDispatcher.dispatch(context, ref, action.id),
      );
    }).toList();

    if (isZipFocused) {
      final extractHereAction = KeyMapActionDefs.getById('extractHere');
      final extractOppositeAction = KeyMapActionDefs.getById(
        'extractToOpposite',
      );

      if (extractHereAction != null && extractOppositeAction != null) {
        actions.insert(
          0,
          AppAction(
            id: extractOppositeAction.id,
            label: extractOppositeAction.label,
            shortcut: settingsNotifier.getEffectiveShortcut(
              extractOppositeAction.id,
            ),
            callback: () => AppActionDispatcher.dispatch(
              context,
              ref,
              extractOppositeAction.id,
            ),
          ),
        );
        actions.insert(
          0,
          AppAction(
            id: extractHereAction.id,
            label: extractHereAction.label,
            shortcut: settingsNotifier.getEffectiveShortcut(
              extractHereAction.id,
            ),
            callback: () => AppActionDispatcher.dispatch(
              context,
              ref,
              extractHereAction.id,
            ),
          ),
        );
      }
    }

    return actions;
  }
}
