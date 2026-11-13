import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fima/domain/entity/panel_tab.dart';
import 'package:fima/domain/entity/remote_connection.dart';
import 'package:fima/infrastructure/repository/compound_file_system_repository.dart';
import 'package:fima/infrastructure/service/remote_session_manager.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/overlay_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';

final remoteSessionManagerProvider = Provider<RemoteSessionManager>((ref) {
  return RemoteSessionManager();
});

/// Request emitted when an SSH tab needs interactive authentication
/// (no saved password or saved password failed).
class SshAuthRequest {
  final String panelId;
  final String tabId;
  final RemoteConnection connection;
  final String targetPath;
  final int requestId;

  const SshAuthRequest({
    required this.panelId,
    required this.tabId,
    required this.connection,
    required this.targetPath,
    required this.requestId,
  });
}

int _nextSshAuthRequestId = 0;

final pendingSshAuthProvider = StateProvider<SshAuthRequest?>((ref) => null);

class PanelTabsState {
  final List<PanelTab> tabs;
  final int activeTabIndex;

  const PanelTabsState({required this.tabs, this.activeTabIndex = 0});

  PanelTab get activeTab {
    final idx = activeTabIndex.clamp(0, tabs.length - 1);
    return tabs[idx];
  }

  String get activeTabId => activeTab.id;

  PanelTabsState copyWith({List<PanelTab>? tabs, int? activeTabIndex}) {
    final nextTabs = tabs ?? this.tabs;
    final nextIdx = (activeTabIndex ?? this.activeTabIndex).clamp(
      0,
      nextTabs.length - 1,
    );
    return PanelTabsState(tabs: nextTabs, activeTabIndex: nextIdx);
  }
}

final panelTabsProvider =
    StateNotifierProvider.family<PanelTabsController, PanelTabsState, String>((
      ref,
      panelId,
    ) {
      return PanelTabsController(ref, panelId);
    });

/// Convenience provider exposing the active tab's ID for [panelId].
final activeTabIdProvider = Provider.family<String, String>((ref, panelId) {
  return ref.watch(panelTabsProvider(panelId).select((s) => s.activeTabId));
});

class PanelTabsController extends StateNotifier<PanelTabsState> {
  final Ref _ref;
  final String _panelId;
  final Set<String> _loadedTabIds = {};
  final Set<String> _loadingTabIds = {};

  PanelTabsController(this._ref, this._panelId)
    : super(_buildInitialState(_ref, _panelId));

  static PanelTabsState _buildInitialState(Ref ref, String panelId) {
    final settings = ref.read(userSettingsProvider);
    final rawTabs = panelId == 'left' ? settings.leftTabs : settings.rightTabs;
    final rawIndex = panelId == 'left'
        ? settings.leftActiveTabIndex
        : settings.rightActiveTabIndex;

    final tabs = rawTabs.isNotEmpty
        ? List<PanelTab>.from(rawTabs)
        : [PanelTab.create(path: '')];
    final activeIndex = rawIndex.clamp(0, tabs.length - 1);
    return PanelTabsState(tabs: tabs, activeTabIndex: activeIndex);
  }

  bool hasTab(String tabId) => state.tabs.any((t) => t.id == tabId);

  void _persist() {
    _ref
        .read(userSettingsProvider.notifier)
        .setPanelTabs(_panelId, state.tabs, state.activeTabIndex);
  }

  /// Ensures the currently active tab has loaded its directory contents
  /// (or reconnects / prompts for SSH auth if needed).
  Future<void> ensureActiveTabLoaded() async {
    await _ensureTabLoaded(state.activeTab);
  }

  Future<void> _ensureTabLoaded(PanelTab tab) async {
    if (_loadingTabIds.contains(tab.id)) return;

    final controller = _ref.read(panelStateProvider(tab.id).notifier);

    if (tab.path.startsWith('ssh://')) {
      _loadingTabIds.add(tab.id);
      try {
        final handled = await _handleSshTabActivation(tab, controller);
        if (handled) {
          _loadedTabIds.add(tab.id);
        }
      } finally {
        _loadingTabIds.remove(tab.id);
      }
      return;
    }

    if (_loadedTabIds.contains(tab.id)) {
      if (controller.needsHiddenFilesRefresh) {
        await controller.refresh();
      }
      return;
    }

    _loadingTabIds.add(tab.id);
    try {
      await controller.initTab(
        panelId: _panelId,
        initialPath: tab.path.isNotEmpty ? tab.path : null,
        sortColumn: tab.sortColumn,
        sortAscending: tab.sortAscending,
      );
      _loadedTabIds.add(tab.id);
    } finally {
      _loadingTabIds.remove(tab.id);
    }
  }

  /// Handles SSH tab activation:
  /// - If already connected, loads/refreshes the remote path.
  /// - If disconnected and password is saved, silently reconnects and loads.
  /// - Otherwise requests interactive authentication via [pendingSshAuthProvider].
  Future<bool> _handleSshTabActivation(
    PanelTab tab,
    PanelController controller,
  ) async {
    final repo = _ref.read(fileSystemRepositoryProvider);
    if (repo is! CompoundFileSystemRepository) return false;

    final sessionManager = _ref.read(remoteSessionManagerProvider);
    final sshRepo = repo.sshRepository;
    final connId = RemoteConnection.connectionIdFromSshUrl(tab.path);

    if (!sshRepo.isConnected(connId)) {
      // Disconnected SSH session — prime UI state with the tab's SSH path
      // and sort so the SSH header and tab title remain visible while connecting.
      controller.primeSshTabState(
        panelId: _panelId,
        sshPath: tab.path,
        sortColumn: tab.sortColumn,
        sortAscending: tab.sortAscending,
      );
    }

    final result = await sessionManager.ensureConnected(
      sshRepository: sshRepo,
      sshUrl: tab.path,
      savedConnections: _ref.read(userSettingsProvider).remoteConnections,
    );

    switch (result.status) {
      case SshConnectionStatus.alreadyConnected:
        if (!_loadedTabIds.contains(tab.id)) {
          await controller.initTab(
            panelId: _panelId,
            initialPath: tab.path,
            sortColumn: tab.sortColumn,
            sortAscending: tab.sortAscending,
          );
        } else if (controller.needsHiddenFilesRefresh) {
          await controller.refresh();
        }
        return true;

      case SshConnectionStatus.reconnected:
        await controller.initTab(
          panelId: _panelId,
          initialPath: tab.path,
          sortColumn: tab.sortColumn,
          sortAscending: tab.sortAscending,
        );
        return true;

      case SshConnectionStatus.connectionNotFound:
        _ref
            .read(overlayProvider.notifier)
            .showToast('Remote connection "$connId" not found', isError: true);
        await controller.initTab(
          panelId: _panelId,
          initialPath: null,
          sortColumn: tab.sortColumn,
          sortAscending: tab.sortAscending,
        );
        return true;

      case SshConnectionStatus.needsPassword:
        final connection = result.connection;
        if (connection == null) return false;
        _nextSshAuthRequestId++;
        _ref.read(pendingSshAuthProvider.notifier).state = SshAuthRequest(
          panelId: _panelId,
          tabId: tab.id,
          connection: connection,
          targetPath: tab.path,
          requestId: _nextSshAuthRequestId,
        );
        return false;
    }
  }

  /// Creates a new tab in this panel duplicating the active tab's folder & sort,
  /// activates it, and persists settings.
  Future<void> createTab({String? path}) async {
    final active = state.activeTab;
    final currentPanelState = _ref.read(panelStateProvider(active.id));
    final targetPath =
        path ??
        (currentPanelState.currentPath.isNotEmpty
            ? currentPanelState.currentPath
            : active.path);

    final newTab = PanelTab.create(
      path: targetPath,
      sortColumn: currentPanelState.sortColumn.index,
      sortAscending: currentPanelState.sortAscending,
    );

    final newTabs = [...state.tabs, newTab];
    state = state.copyWith(tabs: newTabs, activeTabIndex: newTabs.length - 1);
    _persist();
    await ensureActiveTabLoaded();
  }

  /// Closes the tab with [tabId]. No-op if only one tab remains.
  Future<void> closeTab(String tabId) async {
    if (state.tabs.length <= 1) return;

    final removeIdx = state.tabs.indexWhere((t) => t.id == tabId);
    if (removeIdx == -1) return;

    final newTabs = List<PanelTab>.from(state.tabs)..removeAt(removeIdx);
    int newActiveIdx = state.activeTabIndex;
    if (removeIdx < state.activeTabIndex) {
      newActiveIdx = state.activeTabIndex - 1;
    } else if (removeIdx == state.activeTabIndex) {
      newActiveIdx = state.activeTabIndex.clamp(0, newTabs.length - 1);
    }

    _loadedTabIds.remove(tabId);
    _loadingTabIds.remove(tabId);

    state = PanelTabsState(tabs: newTabs, activeTabIndex: newActiveIdx);
    _persist();

    // Dispose the closed tab's controller and file watchers.
    _ref.invalidate(panelStateProvider(tabId));

    await ensureActiveTabLoaded();
  }

  Future<void> closeActiveTab() async {
    await closeTab(state.activeTabId);
  }

  Future<void> selectTab(int index) async {
    if (index < 0 || index >= state.tabs.length) return;
    if (index != state.activeTabIndex) {
      state = state.copyWith(activeTabIndex: index);
      _persist();
    }
    await ensureActiveTabLoaded();
  }

  Future<void> nextTab() async {
    if (state.tabs.length <= 1) return;
    final nextIdx = (state.activeTabIndex + 1) % state.tabs.length;
    await selectTab(nextIdx);
  }

  Future<void> previousTab() async {
    if (state.tabs.length <= 1) return;
    final prevIdx =
        (state.activeTabIndex - 1 + state.tabs.length) % state.tabs.length;
    await selectTab(prevIdx);
  }

  void updateTabPath(String tabId, String path) {
    final idx = state.tabs.indexWhere((t) => t.id == tabId);
    if (idx == -1) return;
    if (state.tabs[idx].path == path) return;

    final updated = List<PanelTab>.from(state.tabs);
    updated[idx] = updated[idx].copyWith(path: path);
    state = state.copyWith(tabs: updated);
    _loadedTabIds.add(tabId);
    _persist();
  }

  void updateTabSort(String tabId, int sortColumn, bool sortAscending) {
    final idx = state.tabs.indexWhere((t) => t.id == tabId);
    if (idx == -1) return;
    final current = state.tabs[idx];
    if (current.sortColumn == sortColumn &&
        current.sortAscending == sortAscending) {
      return;
    }

    final updated = List<PanelTab>.from(state.tabs);
    updated[idx] = current.copyWith(
      sortColumn: sortColumn,
      sortAscending: sortAscending,
    );
    state = state.copyWith(tabs: updated);
    _persist();
  }

  /// Replaces all tabs in this panel (e.g. when loading a workspace).
  Future<void> applyTabs(List<PanelTab> tabs, int activeTabIndex) async {
    final oldTabIds = state.tabs.map((t) => t.id).toList();

    final freshTabs = tabs.isNotEmpty
        ? tabs.map((t) => t.withFreshId()).toList()
        : [PanelTab.create(path: '')];
    final clampedIndex = activeTabIndex.clamp(0, freshTabs.length - 1);

    _loadedTabIds.clear();
    _loadingTabIds.clear();

    state = PanelTabsState(tabs: freshTabs, activeTabIndex: clampedIndex);
    _persist();

    for (final oldId in oldTabIds) {
      _ref.invalidate(panelStateProvider(oldId));
    }

    await ensureActiveTabLoaded();
  }
}
