import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fima/domain/entity/bookmark.dart';
import 'package:fima/domain/entity/remote_connection.dart';
import 'package:fima/domain/entity/workspace.dart';
import 'package:fima/infrastructure/repository/compound_file_system_repository.dart';
import 'package:fima/infrastructure/service/secure_password_service.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/panel_tabs_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/popups/connect_server_dialog.dart';
import 'package:fima/presentation/widgets/popups/text_input_dialog.dart';

/// Encapsulates navigation and CRUD callbacks triggered from [OmniDialog].
class OmniItemActions {
  OmniItemActions._();

  static void navigateToPath(WidgetRef ref, String path) {
    final activePanelId = ref.read(focusProvider.notifier).getActivePanelId();
    final activeTabId = ref.read(panelTabsProvider(activePanelId)).activeTabId;
    ref.read(panelStateProvider(activeTabId).notifier).loadPath(path);
  }

  static void loadWorkspace(WidgetRef ref, Workspace workspace) {
    ref
        .read(panelTabsProvider('left').notifier)
        .applyTabs(workspace.leftTabs, workspace.leftActiveTabIndex);
    ref
        .read(panelTabsProvider('right').notifier)
        .applyTabs(workspace.rightTabs, workspace.rightActiveTabIndex);
  }

  static Future<void> renameWorkspace(
    BuildContext context,
    WidgetRef ref,
    Workspace workspace,
    VoidCallback onUpdated,
  ) async {
    final newName = await showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => TextInputDialog(
        title: 'Rename Workspace',
        label: 'Workspace Name',
        okButtonLabel: 'Rename',
        initialValue: workspace.name,
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      ref
          .read(userSettingsProvider.notifier)
          .updateWorkspace(workspace.name, workspace.copyWith(name: newName));
      onUpdated();
    }
  }

  static Future<void> renameBookmark(
    BuildContext context,
    WidgetRef ref,
    Bookmark bookmark,
    VoidCallback onUpdated,
  ) async {
    final newName = await showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => TextInputDialog(
        title: 'Rename Bookmark',
        label: 'Bookmark Name',
        okButtonLabel: 'Rename',
        initialValue: bookmark.name,
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      ref
          .read(userSettingsProvider.notifier)
          .updateBookmark(bookmark.name, bookmark.copyWith(name: newName));
      onUpdated();
    }
  }

  static Future<void> editConnection(
    BuildContext context,
    RemoteConnection connection,
    VoidCallback onUpdated,
  ) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ConnectServerDialog(existingConnection: connection),
    );
    onUpdated();
  }

  /// Connects to [connection] and navigates the active tab, falling back to
  /// [ConnectServerDialog] on [parentContext] if credentials are missing/stale.
  static Future<void> connectToRemote({
    required BuildContext parentContext,
    required WidgetRef ref,
    required RemoteConnection connection,
  }) async {
    final compoundRepo =
        ref.read(fileSystemRepositoryProvider) as CompoundFileSystemRepository;
    final sshRepo = compoundRepo.sshRepository;
    final activePanelId = ref.read(focusProvider.notifier).getActivePanelId();
    final activeTabId = ref.read(panelTabsProvider(activePanelId)).activeTabId;
    final panelNotifier = ref.read(panelStateProvider(activeTabId).notifier);

    if (!sshRepo.isConnected(connection.id)) {
      String? password;
      if (connection.rememberPassword) {
        password = await SecurePasswordService().getPassword(connection.id);
      }

      if (password != null && password.isNotEmpty) {
        try {
          await sshRepo.connect(connection, password);
        } catch (_) {
          if (parentContext.mounted) {
            showDialog<void>(
              context: parentContext,
              barrierColor: Colors.black54,
              builder: (_) =>
                  ConnectServerDialog(existingConnection: connection),
            );
          }
          return;
        }
      } else {
        if (parentContext.mounted) {
          showDialog<void>(
            context: parentContext,
            barrierColor: Colors.black54,
            builder: (_) => ConnectServerDialog(existingConnection: connection),
          );
        }
        return;
      }
    }

    panelNotifier.loadSshPath(connection);
  }
}
