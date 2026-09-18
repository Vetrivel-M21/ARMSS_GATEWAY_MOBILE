import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/device_auth/device_identity_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/device_access_controller.dart';

/// Shows the interactive Device ID & Token Activation bottom sheet.
void showDeviceTokenModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const DeviceTokenModal(),
  );
}

class DeviceTokenModal extends ConsumerStatefulWidget {
  const DeviceTokenModal({super.key});

  @override
  ConsumerState<DeviceTokenModal> createState() => _DeviceTokenModalState();
}

class _DeviceTokenModalState extends ConsumerState<DeviceTokenModal> {
  String? _deviceName;

  @override
  void initState() {
    super.initState();
    DeviceIdentityService().getDeviceName().then((name) {
      if (mounted) setState(() => _deviceName = name);
    });
  }

  void _copyDeviceId(String deviceId) {
    Clipboard.setData(ClipboardData(text: deviceId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.inkPrimary,
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
            const SizedBox(width: 8),
            Text('Device ID copied: $deviceId'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(deviceAccessControllerProvider);
    final isPending = access.requestStatus == 'pending';
    final isApproved = !access.isRevoked;
    final isRejected = access.requestStatus == 'rejected';

    Color statusColor;
    String statusTitle;
    String statusSubtitle;
    IconData statusIcon;

    if (isApproved) {
      statusColor = const Color(0xFF10B981);
      statusTitle = 'Device Authorized';
      statusSubtitle = 'This device is verified and authorized for portal access.';
      statusIcon = Icons.verified_user_rounded;
    } else if (isPending) {
      statusColor = const Color(0xFFF59E0B);
      statusTitle = 'Approval Pending';
      statusSubtitle = 'Activation request is pending administrator approval.';
      statusIcon = Icons.hourglass_top_rounded;
    } else if (isRejected) {
      statusColor = const Color(0xFFEF4444);
      statusTitle = 'Request Rejected';
      statusSubtitle = access.rejectionReason ?? 'Administrator rejected activation for this device.';
      statusIcon = Icons.cancel_outlined;
    } else {
      statusColor = const Color(0xFF6B7280);
      statusTitle = 'Token Required';
      statusSubtitle = 'This mobile device requires an activation token to access portals.';
      statusIcon = Icons.vpn_key_outlined;
    }

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfacePanel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.phonelink_lock_rounded,
                    color: Color(0xFF0284C7),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device & Token Security',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkPrimary,
                        ),
                      ),
                      Text(
                        'ARMSS Gateway Device Identity',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.inkSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Live Status Hero Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusSubtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Device ID Box with Copy Button and Hardware Name
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceCanvas,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.lineHairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_deviceName != null && _deviceName!.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.smartphone_rounded, size: 16, color: Color(0xFF0284C7)),
                        const SizedBox(width: 6),
                        const Text(
                          'DEVICE MODEL / HARDWARE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _deviceName!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.lineHairline),
                    const SizedBox(height: 12),
                  ],
                  const Text(
                    'DEVICE IDENTIFIER (DEVICE ID)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          access.deviceId.isNotEmpty ? access.deviceId : 'Initializing...',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20, color: Color(0xFF0284C7)),
                        tooltip: 'Copy Device ID',
                        onPressed: access.deviceId.isNotEmpty ? () => _copyDeviceId(access.deviceId) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Feedback Message
            if (access.message != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Text(
                  access.message!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Action Buttons
            if (access.isLoading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else if (access.isRevoked || isPending || isRejected) ...[
              // Request Activation ONLY shown when device access is unapproved or revoked
              if (isPending) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: const Color(0xFFD97706),
                    side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.sync_rounded, size: 18),
                  label: const Text('Check Approval Status', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: () async {
                    await ref.read(deviceAccessControllerProvider.notifier).pollApproval();
                  },
                ),
              ] else ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 1,
                  ),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Request Admin Activation', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: () async {
                    await ref.read(deviceAccessControllerProvider.notifier).requestActivation();
                  },
                ),
              ],
            ] else ...[
              // Device token is active & authorized (automatic upon login)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: const Color(0xFF0284C7),
                  side: const BorderSide(color: Color(0xFF0284C7), width: 1.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Re-check Security Status', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () async {
                  await ref.read(deviceAccessControllerProvider.notifier).checkStatus();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
