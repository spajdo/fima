import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/presentation/providers/overlay_provider.dart';
import 'package:fima/presentation/providers/theme_provider.dart';

const String _defaultBuildName = '1.0.0';
const String _defaultBuildNumber = '1';
const String _repositoryUrl = 'https://github.com/spajdo/fima';
const String _issuesUrl = 'https://github.com/spajdo/fima/issues';

Future<void> showFimaAboutDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => const FimaAboutDialog(),
  );
}

class _AppVersion {
  final String buildName;
  final String buildNumber;

  const _AppVersion({required this.buildName, required this.buildNumber});

  String get formatted => '$buildName ($buildNumber)';
}

class FimaAboutDialog extends ConsumerStatefulWidget {
  const FimaAboutDialog({super.key});

  @override
  ConsumerState<FimaAboutDialog> createState() => _FimaAboutDialogState();
}

class _FimaAboutDialogState extends ConsumerState<FimaAboutDialog> {
  _AppVersion _version = const _AppVersion(
    buildName: _defaultBuildName,
    buildNumber: _defaultBuildNumber,
  );

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final loaded = await _readPlatformAppVersion();
    if (!mounted || loaded == null) return;
    setState(() {
      _version = loaded;
    });
  }

  Future<_AppVersion?> _readPlatformAppVersion() async {
    try {
      if (Platform.isMacOS) {
        final macosDir = p.dirname(Platform.resolvedExecutable);
        final contentsDir = p.dirname(macosDir);
        final plistFile = File(p.join(contentsDir, 'Info.plist'));
        if (!await plistFile.exists()) return null;

        final result = await Process.run('plutil', [
          '-convert',
          'json',
          '-o',
          '-',
          plistFile.path,
        ]);
        if (result.exitCode != 0) return null;

        final decoded = jsonDecode(result.stdout as String);
        if (decoded is! Map<String, dynamic>) return null;
        final name = decoded['CFBundleShortVersionString'] as String?;
        final number = decoded['CFBundleVersion'] as String?;
        if (name == null || name.isEmpty) return null;
        return _AppVersion(
          buildName: name,
          buildNumber: (number != null && number.isNotEmpty)
              ? number
              : _defaultBuildNumber,
        );
      }

      if (Platform.isLinux || Platform.isWindows) {
        final exeDir = p.dirname(Platform.resolvedExecutable);
        final versionFile = File(
          p.join(exeDir, 'data', 'flutter_assets', 'version.json'),
        );
        if (!await versionFile.exists()) return null;

        final decoded = jsonDecode(await versionFile.readAsString());
        if (decoded is! Map<String, dynamic>) return null;
        final name = decoded['version'] as String?;
        final number = decoded['build_number']?.toString();
        if (name == null || name.isEmpty) return null;
        return _AppVersion(
          buildName: name,
          buildNumber: (number != null && number.isNotEmpty)
              ? number
              : _defaultBuildNumber,
        );
      }
    } catch (_) {
      // Fallback to default build metadata when running in test or dev harness.
    }
    return null;
  }

  String _platformLabel() {
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isWindows) return 'Windows';
    return Platform.operatingSystem;
  }

  Future<void> _openUrl(String url) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      }
    } catch (e) {
      debugPrint('Failed to open URL $url: $e');
      _copyText(url, 'URL copied to clipboard');
    }
  }

  void _copyText(String value, String toastMessage) {
    Clipboard.setData(ClipboardData(text: value));
    ref.read(overlayProvider.notifier).showToast(toastMessage);
  }

  void _openLicenses(FimaTheme fimaTheme) {
    final isDark = fimaTheme.backgroundColor.computeLuminance() < 0.5;
    showLicensePage(
      context: context,
      applicationName: 'fima',
      applicationVersion: _version.formatted,
      applicationIcon: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: SvgPicture.asset(
          isDark
              ? 'assets/icons/SVG/fima-dark.svg'
              : 'assets/icons/SVG/fima-light.svg',
          width: 48,
          height: 48,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fimaTheme = ref.watch(themeProvider);
    final isDark = fimaTheme.backgroundColor.computeLuminance() < 0.5;
    final logoAsset = isDark
        ? 'assets/icons/SVG/fima-dark.svg'
        : 'assets/icons/SVG/fima-light.svg';

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Container(
          width: 480,
          decoration: BoxDecoration(
            color: fimaTheme.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: fimaTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: fimaTheme.surfaceColor,
                  border: Border(
                    bottom: BorderSide(color: fimaTheme.borderColor),
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(9),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 17,
                      color: fimaTheme.accentColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'About fima',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: fimaTheme.textColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: fimaTheme.secondaryTextColor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 16,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        children: [
                          SvgPicture.asset(logoAsset, width: 64, height: 64),
                          const SizedBox(height: 12),
                          Text(
                            'fima',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: fimaTheme.textColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Two-panel file manager for keyboard-centric workflows',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: fimaTheme.secondaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: fimaTheme.accentColor.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: fimaTheme.accentColor.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                            child: SelectableText(
                              'Version ${_version.formatted}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: fimaTheme.accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Details card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: fimaTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: fimaTheme.borderColor.withValues(alpha: 0.7),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _AboutInfoRow(
                              label: 'Build',
                              theme: fimaTheme,
                              child: SelectableText(
                                '${_version.buildName} (${_version.buildNumber})',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: fimaTheme.textColor,
                                ),
                              ),
                            ),
                            _AboutInfoRow(
                              label: 'Platform',
                              theme: fimaTheme,
                              child: Text(
                                _platformLabel(),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: fimaTheme.textColor,
                                ),
                              ),
                            ),
                            _AboutInfoRow(
                              label: 'Built with',
                              theme: fimaTheme,
                              child: Text(
                                'Flutter & Dart',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: fimaTheme.textColor,
                                ),
                              ),
                            ),
                            _AboutInfoRow(
                              label: 'Repository',
                              theme: fimaTheme,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _openUrl(_repositoryUrl),
                                      borderRadius: BorderRadius.circular(4),
                                      child: Text(
                                        _repositoryUrl,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: fimaTheme.accentColor,
                                          decoration: TextDecoration.underline,
                                          decorationColor:
                                              fimaTheme.accentColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => _copyText(
                                      _repositoryUrl,
                                      'Repository URL copied',
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Tooltip(
                                      message: 'Copy Repository URL',
                                      child: Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: Icon(
                                          Icons.copy,
                                          size: 13,
                                          color: fimaTheme.secondaryTextColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _AboutInfoRow(
                              label: 'Issues',
                              theme: fimaTheme,
                              child: InkWell(
                                onTap: () => _openUrl(_issuesUrl),
                                borderRadius: BorderRadius.circular(4),
                                child: Text(
                                  'Report a bug or request a feature',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: fimaTheme.accentColor,
                                    decoration: TextDecoration.underline,
                                    decorationColor: fimaTheme.accentColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: fimaTheme.surfaceColor,
                  border: Border(top: BorderSide(color: fimaTheme.borderColor)),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(9),
                  ),
                ),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => _openLicenses(fimaTheme),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: fimaTheme.borderColor),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'Open-Source Licenses',
                        style: TextStyle(
                          fontSize: 12,
                          color: fimaTheme.textColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      autofocus: true,
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: fimaTheme.accentColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutInfoRow extends StatelessWidget {
  final String label;
  final FimaTheme theme;
  final Widget child;

  const _AboutInfoRow({
    required this.label,
    required this.theme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: theme.secondaryTextColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

