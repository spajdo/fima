import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/domain/entity/panel_tab.dart';
import 'package:fima/domain/entity/remote_connection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class PanelTabBar extends StatelessWidget {
  final List<PanelTab> tabs;
  final int activeTabIndex;
  final FimaTheme fimaTheme;
  final double fontSize;
  final List<RemoteConnection> remoteConnections;
  final ValueChanged<int> onSelectTab;
  final ValueChanged<String> onCloseTab;

  static const double _minTabWidth = 84.0;
  static const double _maxTabWidth = 180.0;
  static const double _overflowButtonWidth = 28.0;
  static const double _tabBarHeight = 28.0;

  const PanelTabBar({
    super.key,
    required this.tabs,
    required this.activeTabIndex,
    required this.fimaTheme,
    required this.fontSize,
    required this.remoteConnections,
    required this.onSelectTab,
    required this.onCloseTab,
  });

  double _measureTabWidth(PanelTab tab, TextStyle textStyle) {
    final title = PanelTab.displayNameForPath(
      tab.path,
      remoteConnections: remoteConnections,
    );
    final painter = TextPainter(
      text: TextSpan(text: title, style: textStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    final sshIconSpace = tab.path.startsWith('ssh://') ? 18.0 : 0.0;
    // Horizontal padding (16) + close icon (14) + gap (6) + border (1)
    final rawWidth = painter.width + sshIconSpace + 37.0;
    return rawWidth.clamp(_minTabWidth, _maxTabWidth);
  }

  _TabLayoutPlan _computeLayoutPlan(
    double maxWidth,
    List<double> desiredWidths,
  ) {
    final totalDesired = desiredWidths.fold<double>(0.0, (a, b) => a + b);
    if (totalDesired <= maxWidth) {
      return _TabLayoutPlan(
        visibleIndices: List.generate(tabs.length, (i) => i),
        hiddenIndices: const [],
        tabWidths: desiredWidths,
      );
    }

    final available = (maxWidth - _overflowButtonWidth).clamp(
      0.0,
      double.infinity,
    );
    final safeActive = activeTabIndex.clamp(0, tabs.length - 1);

    int start = safeActive;
    int end = safeActive;
    double used = desiredWidths[safeActive].clamp(0.0, available);
    bool tryRight = true;

    while (true) {
      bool expanded = false;
      if (tryRight && end + 1 < tabs.length) {
        final w = desiredWidths[end + 1];
        if (used + w <= available) {
          used += w;
          end++;
          expanded = true;
        }
      } else if (!tryRight && start > 0) {
        final w = desiredWidths[start - 1];
        if (used + w <= available) {
          used += w;
          start--;
          expanded = true;
        }
      }

      if (!expanded) {
        if (end + 1 < tabs.length &&
            used + desiredWidths[end + 1] <= available) {
          used += desiredWidths[end + 1];
          end++;
          expanded = true;
        } else if (start > 0 && used + desiredWidths[start - 1] <= available) {
          used += desiredWidths[start - 1];
          start--;
          expanded = true;
        }
      }

      if (!expanded) break;
      tryRight = !tryRight;
    }

    final visibleIndices = [for (int i = start; i <= end; i++) i];
    final hiddenIndices = [
      for (int i = 0; i < start; i++) i,
      for (int i = end + 1; i < tabs.length; i++) i,
    ];

    final adjustedWidths = List<double>.from(desiredWidths);
    if (visibleIndices.length == 1 && available > 0) {
      adjustedWidths[safeActive] = desiredWidths[safeActive].clamp(
        0.0,
        available,
      );
    }

    return _TabLayoutPlan(
      visibleIndices: visibleIndices,
      hiddenIndices: hiddenIndices,
      tabWidths: adjustedWidths,
    );
  }

  Future<void> _showOverflowMenu(
    BuildContext buttonContext,
    List<int> hiddenIndices,
  ) async {
    final renderBox = buttonContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final offset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + renderBox.size.height,
      overlay.size.width - offset.dx - renderBox.size.width,
      overlay.size.height - offset.dy - renderBox.size.height,
    );

    final selected = await showMenu<int>(
      context: buttonContext,
      position: position,
      color: fimaTheme.backgroundColor,
      items: hiddenIndices.map((index) {
        final tab = tabs[index];
        final title = PanelTab.displayNameForPath(
          tab.path,
          remoteConnections: remoteConnections,
        );
        final subtitle = tab.path.isEmpty ? 'Home' : tab.path;
        final isSsh = tab.path.startsWith('ssh://');

        return PopupMenuItem<int>(
          value: index,
          height: 40,
          child: Row(
            children: [
              Icon(
                isSsh ? Icons.dns : Icons.folder_outlined,
                size: 14,
                color: isSsh
                    ? fimaTheme.accentColor
                    : fimaTheme.secondaryTextColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: fimaTheme.textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: fimaTheme.secondaryTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () {
                  Navigator.of(buttonContext).pop();
                  onCloseTab(tab.id);
                },
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 13,
                    color: fimaTheme.secondaryTextColor,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );

    if (selected != null) {
      onSelectTab(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (tabs.length <= 1) {
      return const SizedBox.shrink();
    }

    final tabFontSize = (fontSize - 2).clamp(11.0, 13.0);
    final labelStyle = TextStyle(
      fontSize: tabFontSize,
      fontWeight: FontWeight.w500,
    );

    return Container(
      height: _tabBarHeight,
      decoration: BoxDecoration(
        color: fimaTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: fimaTheme.borderColor)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desiredWidths = tabs
              .map((t) => _measureTabWidth(t, labelStyle))
              .toList();
          final plan = _computeLayoutPlan(constraints.maxWidth, desiredWidths);

          return Row(
            children: [
              for (final index in plan.visibleIndices)
                SizedBox(
                  width: plan.tabWidths[index],
                  height: _tabBarHeight,
                  child: _TabChip(
                    tab: tabs[index],
                    title: PanelTab.displayNameForPath(
                      tabs[index].path,
                      remoteConnections: remoteConnections,
                    ),
                    isActive: index == activeTabIndex,
                    fimaTheme: fimaTheme,
                    fontSize: tabFontSize,
                    onTap: () => onSelectTab(index),
                    onClose: () => onCloseTab(tabs[index].id),
                  ),
                ),
              const Spacer(),
              if (plan.hiddenIndices.isNotEmpty)
                Builder(
                  builder: (buttonCtx) => Tooltip(
                    message: 'Hidden tabs (${plan.hiddenIndices.length})',
                    child: InkWell(
                      onTap: () =>
                          _showOverflowMenu(buttonCtx, plan.hiddenIndices),
                      child: SizedBox(
                        width: _overflowButtonWidth,
                        height: _tabBarHeight,
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: fimaTheme.textColor,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TabLayoutPlan {
  final List<int> visibleIndices;
  final List<int> hiddenIndices;
  final List<double> tabWidths;

  const _TabLayoutPlan({
    required this.visibleIndices,
    required this.hiddenIndices,
    required this.tabWidths,
  });
}

class _TabChip extends StatefulWidget {
  final PanelTab tab;
  final String title;
  final bool isActive;
  final FimaTheme fimaTheme;
  final double fontSize;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabChip({
    required this.tab,
    required this.title,
    required this.isActive,
    required this.fimaTheme,
    required this.fontSize,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _isHovered = false;
  bool _isCloseHovered = false;

  @override
  Widget build(BuildContext context) {
    final fimaTheme = widget.fimaTheme;
    final isSsh = widget.tab.path.startsWith('ssh://');
    final tooltipText = widget.tab.path.isEmpty ? 'Home' : widget.tab.path;

    return Tooltip(
      message: tooltipText,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Listener(
          onPointerDown: (event) {
            if (event.buttons == kMiddleMouseButton) {
              widget.onClose();
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: widget.isActive
                    ? fimaTheme.backgroundColor
                    : (_isHovered
                          ? fimaTheme.backgroundColor.withValues(alpha: 0.5)
                          : fimaTheme.surfaceColor),
                border: Border(
                  top: BorderSide(
                    color: widget.isActive
                        ? fimaTheme.accentColor
                        : Colors.transparent,
                    width: 2,
                  ),
                  right: BorderSide(color: fimaTheme.borderColor),
                ),
              ),
              child: Row(
                children: [
                  if (isSsh) ...[
                    Icon(Icons.dns, size: 12, color: fimaTheme.accentColor),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: widget.fontSize,
                        fontWeight: widget.isActive
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: widget.isActive || _isHovered
                            ? fimaTheme.textColor
                            : fimaTheme.secondaryTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  MouseRegion(
                    onEnter: (_) => setState(() => _isCloseHovered = true),
                    onExit: (_) => setState(() => _isCloseHovered = false),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onClose,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: _isCloseHovered
                              ? fimaTheme.borderColor.withValues(alpha: 0.6)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 12,
                          color: _isCloseHovered
                              ? fimaTheme.textColor
                              : fimaTheme.secondaryTextColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
