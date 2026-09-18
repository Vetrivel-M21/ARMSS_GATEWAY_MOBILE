import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../controllers/device_access_controller.dart';
import 'device_token_modal.dart';

/// Compact, interactive chip showing Device ID and token activation status.
/// Tapping it opens the DeviceTokenModal bottom sheet.
class DeviceIdChip extends ConsumerWidget {
  final bool isCompact;

  const DeviceIdChip({
    super.key,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(deviceAccessControllerProvider);
    final isPending = access.requestStatus == 'pending';
    final isApproved = !access.isRevoked;
    final isRejected = access.requestStatus == 'rejected';

    Color dotColor;
    String statusText;

    if (isApproved) {
      dotColor = const Color(0xFF10B981);
      statusText = 'Active';
    } else if (isPending) {
      dotColor = const Color(0xFFF59E0B);
      statusText = 'Pending';
    } else if (isRejected) {
      dotColor = const Color(0xFFEF4444);
      statusText = 'Rejected';
    } else {
      dotColor = const Color(0xFF9CA3AF);
      statusText = 'Token Req';
    }

    final devId = access.deviceId.isNotEmpty ? access.deviceId : 'Device ID';
    final shortId = devId.length > 14
        ? '${devId.substring(0, 7)}...${devId.substring(devId.length - 4)}'
        : devId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showDeviceTokenModal(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 12,
            vertical: isCompact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: dotColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: dotColor.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status glowing dot
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Text(
                isCompact ? shortId : '$shortId ($statusText)',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: isCompact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.touch_app_outlined,
                size: isCompact ? 12 : 14,
                color: dotColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ultra-compact status icon button for Mobile AppBar.
/// Shows device security icon with live status dot and prevents any title overlap.
class DeviceStatusIconButton extends ConsumerWidget {
  const DeviceStatusIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(deviceAccessControllerProvider);
    final isPending = access.requestStatus == 'pending';
    final isApproved = !access.isRevoked;
    final isRejected = access.requestStatus == 'rejected';

    Color dotColor;
    if (isApproved) {
      dotColor = const Color(0xFF10B981);
    } else if (isPending) {
      dotColor = const Color(0xFFF59E0B);
    } else if (isRejected) {
      dotColor = const Color(0xFFEF4444);
    } else {
      dotColor = const Color(0xFF9CA3AF);
    }

    return IconButton(
      tooltip: isApproved
          ? 'Device Authorized (Tap for ID)'
          : (isPending ? 'Activation Pending' : 'Device Token Required'),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.phonelink_lock_rounded,
            size: 21,
            color: AppColors.inkPrimary,
          ),
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withValues(alpha: 0.6),
                    blurRadius: 3,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      onPressed: () => showDeviceTokenModal(context),
    );
  }
}
