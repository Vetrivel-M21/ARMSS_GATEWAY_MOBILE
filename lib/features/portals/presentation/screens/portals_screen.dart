import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/device_auth/gated_link_launcher.dart';
import '../../../../core/portal_links/portal_link_registry.dart';
import '../../../../core/portal_links/portal_link_catalog_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared_widgets/page_header.dart';
import '../../../../shared_widgets/portal_link_grid.dart';
import '../../../device_activation/presentation/controllers/device_access_controller.dart';
import '../../../portal_auth/presentation/controllers/portal_auth_controllers.dart';

/// Unified Portals screen for portal users.
///
/// Instead of displaying individual tabs named after people/departments,
/// this screen displays all web sites and enterprise systems that have
/// been granted to the currently logged-in account.
///
/// If no sites are currently granted to the user, an informative empty state
/// advises them to contact their administrator, with an immediate refresh option.
class PortalsScreen extends ConsumerStatefulWidget {
  const PortalsScreen({super.key});

  @override
  ConsumerState<PortalsScreen> createState() => _PortalsScreenState();
}

class _PortalsScreenState extends ConsumerState<PortalsScreen> {
  List<PortalLink>? _catalog;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final links = await PortalLinkCatalogRepository().listActive();
      if (mounted) setState(() => _catalog = links);
    } catch (_) {
      if (mounted) setState(() => _catalog = kAllPortalLinks);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(portalSessionControllerProvider).valueOrNull;
    final isAdmin = session?.isAdmin ?? false;

    final grantedKeys = session?.grantedLinkKeys.toSet() ?? const <String>{};

    // If portal admin, show all links.
    // For regular portal user, show ONLY the links whose keys have been explicitly granted.
    final catalog = _catalog ?? kAllPortalLinks;
    final visibleLinks = isAdmin
        ? catalog
        : catalog.where((link) => grantedKeys.contains(link.key)).toList();

    final filteredLinks = _searchQuery.trim().isEmpty
        ? visibleLinks
        : visibleLinks
            .where((l) =>
                l.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMobile)
              const PageHeader(
                title: 'Portals',
                icon: Icons.apps_outlined,
                accentColor: Color(0xFF0284C7),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.grid_view_rounded, size: 20, color: Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    const Text(
                      'Available Portals',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${visibleLinks.length} apps',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Search Filter
            if (visibleLinks.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 16 : 20,
                  0,
                  isMobile ? 16 : 20,
                  isMobile ? 10 : 16,
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search portals & internal apps...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.inkSecondary),
                    filled: true,
                    fillColor: AppColors.surfacePanel,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.lineHairline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.lineHairline),
                    ),
                  ),
                ),
              ),

            Expanded(
              child: visibleLinks.isEmpty
                  ? _NoPortalsEmptyState(
                      onRefresh: () async {
                        ref.invalidate(portalSessionControllerProvider);
                        await _loadCatalog();
                        await ref
                            .read(deviceAccessControllerProvider.notifier)
                            .checkStatus();
                        ref
                            .read(appRefreshSignalProvider.notifier)
                            .update((v) => v + 1);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Portal access permissions refreshed.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    )
                  : filteredLinks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.search_off_rounded, size: 40, color: AppColors.inkMuted),
                              const SizedBox(height: 8),
                              Text(
                                'No portals match "$_searchQuery"',
                                style: const TextStyle(color: AppColors.inkSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : isMobile
                          ? GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: constraints.maxWidth < 360 ? 1 : 2,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: constraints.maxWidth < 360 ? 2.2 : 0.95,
                              ),
                              itemCount: filteredLinks.length,
                              itemBuilder: (context, index) {
                                final link = filteredLinks[index];
                                return PortalCardTile(
                                  name: link.name,
                                  icon: link.icon,
                                  color: link.color,
                                  imageUrl: link.imageUrl,
                                  onTap: () => launchGatedPortalLink(context, link),
                                );
                              },
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              child: Wrap(
                                spacing: AppSpacing.lg,
                                runSpacing: AppSpacing.lg,
                                children: [
                                  for (final link in filteredLinks)
                                    SizedBox(
                                      width: 200,
                                      height: 164,
                                      child: PortalCardTile(
                                        name: link.name,
                                        icon: link.icon,
                                        color: link.color,
                                        imageUrl: link.imageUrl,
                                        onTap: () => launchGatedPortalLink(context, link),
                                      ),
                                    ),
                                ],
                              ),
                            ),
            ),
          ],
        );
      },
    );
  }
}

class _NoPortalsEmptyState extends StatefulWidget {
  final Future<void> Function() onRefresh;

  const _NoPortalsEmptyState({required this.onRefresh});

  @override
  State<_NoPortalsEmptyState> createState() => _NoPortalsEmptyStateState();
}

class _NoPortalsEmptyStateState extends State<_NoPortalsEmptyState> {
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
          decoration: BoxDecoration(
            color: AppColors.surfacePanel,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.softShadow(),
            border: Border.all(color: AppColors.lineHairline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.vpn_lock_outlined,
                  size: 32,
                  color: Color(0xFF0284C7),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Portals Assigned',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'No sites are provided to your account. Please contact your system administrator to grant access to the required portals.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.inkSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('Check for Updates'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isRefreshing
                    ? null
                    : () async {
                        setState(() => _isRefreshing = true);
                        try {
                          await widget.onRefresh();
                        } finally {
                          if (mounted) setState(() => _isRefreshing = false);
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
