import 'package:flutter/material.dart';

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/infrastructure/service/item_metadata_service.dart';
import 'package:fima/presentation/widgets/popups/info/info_section_card.dart';

/// Displays MD5 / SHA-256 calculation controls, hash results, and verification input.
class InfoChecksumsSection extends StatelessWidget {
  final FimaTheme fimaTheme;
  final FileChecksums? checksums;
  final bool isCalculating;
  final String? error;
  final TextEditingController verifyHashController;
  final String verifyHashInput;
  final VoidCallback onCalculate;
  final void Function(String label, String hashValue) onCopyHash;
  final ValueChanged<String> onVerifyInputChanged;

  const InfoChecksumsSection({
    super.key,
    required this.fimaTheme,
    required this.checksums,
    required this.isCalculating,
    required this.error,
    required this.verifyHashController,
    required this.verifyHashInput,
    required this.onCalculate,
    required this.onCopyHash,
    required this.onVerifyInputChanged,
  });

  (String?, Color?) _evaluateVerification() {
    if (checksums == null) return (null, null);
    final query = verifyHashInput.trim().toLowerCase();
    if (query.isEmpty) return (null, null);
    if (query == checksums!.md5Hex.toLowerCase()) {
      return ('Matches MD5', Colors.green);
    }
    if (query == checksums!.sha256Hex.toLowerCase()) {
      return ('Matches SHA-256', Colors.green);
    }
    return ('Does not match', Colors.redAccent);
  }

  Widget _buildHashRow(String label, String hashValue) {
    return InfoRowWidget(
      label: label,
      theme: fimaTheme,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              hashValue,
              style: TextStyle(
                fontSize: 11.5,
                fontFamily: 'monospace',
                color: fimaTheme.textColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => onCopyHash(label, hashValue),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.copy,
                size: 13,
                color: fimaTheme.secondaryTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (verifyStatusText, verifyStatusColor) = _evaluateVerification();

    return InfoSectionCard(
      title: 'CHECKSUMS',
      theme: fimaTheme,
      children: [
        if (checksums == null && !isCalculating)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onCalculate,
              icon: Icon(
                Icons.fingerprint,
                size: 15,
                color: fimaTheme.accentColor,
              ),
              label: Text(
                'Calculate MD5 & SHA-256',
                style: TextStyle(fontSize: 12, color: fimaTheme.textColor),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: fimaTheme.borderColor),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        if (isCalculating)
          Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: fimaTheme.accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Calculating MD5 & SHA-256...',
                style: TextStyle(
                  fontSize: 12.5,
                  color: fimaTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
          ),
        ],
        if (checksums != null) ...[
          _buildHashRow('MD5', checksums!.md5Hex),
          _buildHashRow('SHA-256', checksums!.sha256Hex),
          const SizedBox(height: 8),
          InfoRowWidget(
            label: 'Verify Hash',
            theme: fimaTheme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: verifyHashController,
                  onChanged: onVerifyInputChanged,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    color: fimaTheme.textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Paste expected MD5 or SHA-256 hash...',
                    hintStyle: TextStyle(
                      fontSize: 11.5,
                      fontFamily: null,
                      color: fimaTheme.secondaryTextColor,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 7,
                    ),
                    filled: true,
                    fillColor: fimaTheme.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(color: fimaTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(
                        color: verifyStatusColor ?? fimaTheme.borderColor,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(
                        color: verifyStatusColor ?? fimaTheme.accentColor,
                      ),
                    ),
                  ),
                ),
                if (verifyStatusText != null && verifyStatusColor != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        verifyStatusColor == Colors.green
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        size: 13,
                        color: verifyStatusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        verifyStatusText,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: verifyStatusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
