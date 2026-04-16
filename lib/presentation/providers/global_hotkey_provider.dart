import 'package:fima/domain/entity/key_map_action.dart';
import 'package:fima/infrastructure/service/global_hotkey_service.dart';
import 'package:fima/infrastructure/service/window_toggle_service.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final globalHotkeyServiceProvider = Provider<GlobalHotkeyService>((ref) {
  if (!GlobalHotkeyService.isSupported) {
    debugPrint('GlobalHotkeyService: platform not supported, skipping');
    return GlobalHotkeyService(onToggleWindow: () {});
  }

  final toggleService = WindowToggleService();
  final service = GlobalHotkeyService(
    onToggleWindow: () => toggleService.toggle(),
  );

  // Register the initial hotkey once settings are available
  final shortcut = ref
      .read(userSettingsProvider.notifier)
      .getEffectiveShortcut('globalToggleWindow');
  if (shortcut != null && shortcut.isNotEmpty) {
    service.register(shortcut);
  }

  // Re-register whenever the user changes the shortcut in settings
  ref.listen<Map<String, String>>(
    userSettingsProvider.select((s) => s.keyMap),
    (previous, next) {
      final prevShortcut = previous?['globalToggleWindow'];
      final nextShortcut = next['globalToggleWindow'];
      if (prevShortcut != nextShortcut) {
        final effectiveShortcut = ref
            .read(userSettingsProvider.notifier)
            .getEffectiveShortcut('globalToggleWindow');

        if (effectiveShortcut != null && effectiveShortcut.isNotEmpty) {
          service.updateShortcut(effectiveShortcut).then((success) {
            if (!success) {
              debugPrint(
                'GlobalHotkeyService: failed to register updated shortcut',
              );
            }
          });
        } else {
          service.unregister();
        }
      }
    },
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Notifies the global hotkey service that a shortcut change was applied
/// and returns whether the re-registration succeeded.
/// Used by the Key Map Tab to surface errors to the user.
Future<bool> reregisterGlobalHotkey(WidgetRef ref) async {
  if (!GlobalHotkeyService.isSupported) return true;

  final service = ref.read(globalHotkeyServiceProvider);
  final shortcut = ref
      .read(userSettingsProvider.notifier)
      .getEffectiveShortcut('globalToggleWindow');

  if (shortcut == null || shortcut.isEmpty) {
    await service.unregister();
    return true;
  }

  return service.updateShortcut(shortcut);
}

/// Returns whether the global hotkey for [actionId] failed to register,
/// so the UI can show an error.
bool isGlobalAction(String actionId) {
  return KeyMapActionDefs.getById(actionId)?.isGlobal ?? false;
}
