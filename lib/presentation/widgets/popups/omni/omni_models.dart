import 'package:flutter/material.dart';

enum OmniMode { path, action, workspace, remote, bookmark }

enum WorkspaceAction { none, edit, delete }

/// Derives [OmniMode] metadata (prefix stripping, hint text, icon) from query text.
class OmniModeSpec {
  final OmniMode mode;
  final String query;
  final String hintText;
  final IconData? prefixIcon;

  const OmniModeSpec({
    required this.mode,
    required this.query,
    required this.hintText,
    this.prefixIcon,
  });

  bool get supportsInlineActions =>
      mode == OmniMode.workspace ||
      mode == OmniMode.bookmark ||
      mode == OmniMode.remote;

  static OmniModeSpec fromInput(String text) {
    if (text.startsWith('w ')) {
      return OmniModeSpec(
        mode: OmniMode.workspace,
        query: text.substring(2).toLowerCase(),
        hintText: 'Search workspaces...',
        prefixIcon: Icons.work,
      );
    }
    if (text.startsWith('b ')) {
      return OmniModeSpec(
        mode: OmniMode.bookmark,
        query: text.substring(2).toLowerCase(),
        hintText: 'Search bookmarks...',
        prefixIcon: Icons.bookmark,
      );
    }
    if (text.startsWith('r ')) {
      return OmniModeSpec(
        mode: OmniMode.remote,
        query: text.substring(2).toLowerCase(),
        hintText: 'Search connections...',
        prefixIcon: Icons.dns,
      );
    }
    if (text.startsWith('>')) {
      return OmniModeSpec(
        mode: OmniMode.action,
        query: text.substring(1).toLowerCase(),
        hintText: 'Type to search...',
      );
    }
    return OmniModeSpec(
      mode: OmniMode.path,
      query: text.toLowerCase(),
      hintText: 'Type to search...',
    );
  }
}
