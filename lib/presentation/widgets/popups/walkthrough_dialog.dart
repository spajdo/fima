import 'dart:io';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WalkthroughDialog extends ConsumerStatefulWidget {
  const WalkthroughDialog({super.key});

  @override
  ConsumerState<WalkthroughDialog> createState() => _WalkthroughDialogState();
}

class _WalkthroughDialogState extends ConsumerState<WalkthroughDialog> {
  bool _dontShowAgain = false;
  final FocusNode _getStartedFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getStartedFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _getStartedFocusNode.dispose();
    super.dispose();
  }

  void _onDismiss() {
    if (_dontShowAgain) {
      ref
          .read(userSettingsProvider.notifier)
          .setShowWalkthroughOnStartup(false);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final isMac = Platform.isMacOS;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 600,
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                border: Border(bottom: BorderSide(color: theme.borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/SVG/fima-dark.svg',
                      width: 32,
                      height: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome to fima',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.textColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Master these shortcuts to supercharge your workflow.',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShortcutHint(
                    context,
                    theme,
                    title: 'Jump to folder',
                    description:
                        'Instantly find and navigate to any previously visited folder.',
                    keys: isMac ? ['⌘', 'P'] : ['Ctrl', 'P'],
                    icon: Icons.folder_open,
                  ),
                  const SizedBox(height: 24),
                  _buildShortcutHint(
                    context,
                    theme,
                    title: 'Actions Menu',
                    description:
                        'Quickly access all application actions from a command palette.',
                    keys: isMac ? ['⌘', '⇧', 'P'] : ['Ctrl', 'Shift', 'P'],
                    icon: Icons.bolt,
                  ),
                  const SizedBox(height: 24),
                  _buildShortcutHint(
                    context,
                    theme,
                    title: 'Quick Filter',
                    description:
                        'Just start typing to instantly filter items in the active panel.',
                    keys: ['Type any text'],
                    icon: Icons.filter_alt_outlined,
                    isWide: true,
                  ),
                  const SizedBox(height: 24),
                  _buildShortcutHint(
                    context,
                    theme,
                    title: 'Jump to Top & Bottom',
                    description:
                        'Quickly scroll to the extreme ends of the file list.',
                    keys: ['Arrow Left', 'Arrow Right'],
                    icon: Icons.swap_vert,
                    isWide: true,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Pro tip: Press F1 anytime to view all shortcuts.',
                      style: TextStyle(
                        color: theme.accentColor,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: theme.surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(15),
                ),
                border: Border(top: BorderSide(color: theme.borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _dontShowAgain = !_dontShowAgain;
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _dontShowAgain
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: _dontShowAgain
                                ? theme.accentColor
                                : theme.secondaryTextColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Don't show this again",
                            style: TextStyle(
                              color: _dontShowAgain
                                  ? theme.textColor
                                  : theme.secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  FilledButton(
                    focusNode: _getStartedFocusNode,
                    onPressed: _onDismiss,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      backgroundColor: theme.accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutHint(
    BuildContext context,
    dynamic theme, {
    required String title,
    required String description,
    required List<String> keys,
    required IconData icon,
    bool isWide = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.secondaryTextColor, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.secondaryTextColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: keys.map((key) {
            final isLast = key == keys.last;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildKeyLabel(key, theme, isWide: isWide),
                if (!isLast && !isWide) ...[
                  const SizedBox(width: 4),
                  Text(
                    '+',
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (!isLast && isWide) ...[
                  const SizedBox(width: 8),
                  Text(
                    'or',
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildKeyLabel(String label, dynamic theme, {bool isWide = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 12 : 12,
        vertical: isWide ? 8 : 8,
      ),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: theme.backgroundColor,
            offset: const Offset(0, 2),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 3),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: theme.textColor,
          fontSize: 13,
          fontWeight: isWide ? FontWeight.w500 : FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
