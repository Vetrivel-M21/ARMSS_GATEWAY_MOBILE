import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// "Page title [Primary action]" row — every screen under the nav rail
/// starts with this instead of its own `AppBar`, since the persistent top
/// bar (`app_shell.dart`) now owns that role. Optionally shows a small
/// colored icon next to the title (matching that screen's nav-rail icon)
/// and a thin colored underline, tying the section's identity color through
/// from the nav rail into its own content.
class PageHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final IconData? icon;
  final Color? accentColor;

  const PageHeader({super.key, required this.title, this.actions = const [], this.icon, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 650;
    final color = accentColor ?? AppColors.accentLedger;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : AppSpacing.md),
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : AppSpacing.xl,
        isMobile ? 10 : AppSpacing.lg,
        isMobile ? 16 : AppSpacing.xl,
        isMobile ? 10 : AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfacePanel,
        border: Border(
          bottom: BorderSide(
            color: color.withValues(alpha: 0.18),
            width: isMobile ? 1.2 : 2,
          ),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: isMobile ? 32 : 36,
              height: isMobile ? 32 : 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
              ),
              child: Icon(icon, size: isMobile ? 17 : 20, color: color),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 16 : 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: AppColors.inkPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final action in actions)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: action,
            ),
        ],
      ),
    );
  }
}
