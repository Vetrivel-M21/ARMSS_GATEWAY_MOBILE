import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/updates/mobile_update_service.dart';

/// Helper to display the update dialog
Future<void> showAppUpdateDialog(
  BuildContext context, {
  required MobileUpdateInfo updateInfo,
  required String currentVersion,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => UpdateDialog(
      updateInfo: updateInfo,
      currentVersion: currentVersion,
    ),
  );
}

class UpdateDialog extends StatefulWidget {
  final MobileUpdateInfo updateInfo;
  final String currentVersion;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.currentVersion,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final _updateService = MobileUpdateService();

  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = '';
  String? _errorMessage;
  bool _needsInstallPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    if (Platform.isAndroid) {
      final canInstall = await _updateService.canRequestPackageInstalls();
      if (mounted) {
        setState(() {
          _needsInstallPermission = !canInstall;
        });
      }
    }
  }

  Future<void> _startUpdate() async {
    if (_needsInstallPermission) {
      await _updateService.openInstallPermissionSettings();
      // Recheck permission after returning from settings
      await _checkPermission();
      if (_needsInstallPermission) {
        setState(() {
          _statusMessage = 'Please allow app install permission in Settings to continue.';
        });
        return;
      }
    }

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _errorMessage = null;
      _statusMessage = 'Starting download...';
    });

    try {
      await _updateService.downloadAndInstall(
        widget.updateInfo,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              if (total > 0) {
                _progress = received / total;
                final receivedMb = (received / (1024 * 1024)).toStringAsFixed(1);
                final totalMb = (total / (1024 * 1024)).toStringAsFixed(1);
                _statusMessage =
                    'Downloading: ${(_progress * 100).toInt()}% ($receivedMb / $totalMb MB)';
              } else {
                final receivedMb = (received / (1024 * 1024)).toStringAsFixed(1);
                _statusMessage = 'Downloading: $receivedMb MB...';
              }
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'Launching installer... Follow on-screen prompts.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _statusMessage = 'Update failed';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.surfacePanel,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.system_update_rounded,
              color: Color(0xFF10B981),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update Available',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkPrimary,
                  ),
                ),
                Text(
                  'ARMSS Gateway Mobile',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // Version badge row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceSunken,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lineHairline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CURRENT VERSION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'v${widget.currentVersion}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: AppColors.inkMuted,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'NEW VERSION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'v${widget.updateInfo.version}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (widget.updateInfo.sha256.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  size: 14,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Integrity Verified (SHA-256 checksum protection)',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Download Progress / Status
          if (_isDownloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 8,
                backgroundColor: AppColors.surfaceSunken,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _statusMessage,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.inkSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ] else if (_statusMessage.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _errorMessage != null
                    ? Colors.red.withValues(alpha: 0.08)
                    : const Color(0xFF10B981).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage ?? _statusMessage,
                style: TextStyle(
                  fontSize: 12,
                  color: _errorMessage != null ? Colors.red.shade700 : const Color(0xFF047857),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          // Permission warning if needed
          if (_needsInstallPermission && !_isDownloading) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Android requires permission to install APK updates directly.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!_isDownloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later', style: TextStyle(color: AppColors.inkSecondary)),
          ),
        if (!_isDownloading)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(
              _errorMessage != null
                  ? Icons.refresh_rounded
                  : _needsInstallPermission
                      ? Icons.settings_rounded
                      : Icons.download_rounded,
              size: 18,
            ),
            label: Text(
              _errorMessage != null
                  ? 'Retry'
                  : _needsInstallPermission
                      ? 'Allow & Update'
                      : 'Update Now',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: _startUpdate,
          ),
      ],
    );
  }
}
