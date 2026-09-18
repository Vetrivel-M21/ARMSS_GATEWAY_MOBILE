import 'package:flutter/material.dart';

import '../core/device_auth/gated_link_launcher.dart';
import '../core/theme/app_theme.dart';

/// A single external app: opens in the system default browser, no
/// device-token gate, no embedded WebView — shared by every "portal
/// launcher" style tab (Abi Portal, Kavi Manju Portal, ...). `key` is a
/// stable identifier (never shown in the UI) that the ARMSS Gateway backend
/// uses to record per-user access grants — see `filterGrantedCategories`.
class PortalLink {
  final String key;
  final String name;
  final String url;
  final IconData icon;
  final Color color;
  final String? imageUrl;
  final String? tabName;
  const PortalLink({
    required this.key,
    required this.name,
    required this.url,
    required this.icon,
    required this.color,
    this.imageUrl,
    this.tabName,
  });

  PortalLink copyWith({
    String? key,
    String? name,
    String? url,
    IconData? icon,
    Color? color,
    String? imageUrl,
    String? tabName,
  }) {
    return PortalLink(
      key: key ?? this.key,
      name: name ?? this.name,
      url: url ?? this.url,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      imageUrl: imageUrl ?? this.imageUrl,
      tabName: tabName ?? this.tabName,
    );
  }
}

class PortalCategory {
  final String name;
  final IconData icon;
  final List<PortalLink> links;
  const PortalCategory({
    required this.name,
    required this.icon,
    required this.links,
  });
}

/// Keeps only the links whose `key` is in `grantedKeys` — used by every
/// portal-tab screen to show a logged-in portal user just what an admin has
/// granted them, per link, not per tab.
List<PortalCategory> filterGrantedCategories(
  List<PortalCategory> categories,
  List<String> grantedKeys,
) {
  final granted = grantedKeys.toSet();
  return [
    for (final category in categories)
      PortalCategory(
        name: category.name,
        icon: category.icon,
        links: category.links.where((l) => granted.contains(l.key)).toList(),
      ),
  ];
}

/// Renders every app across all categories as one continuous flowing grid —
/// no section headers or dividers between categories, just a single wrap of
/// cards — the shared body for any "portal launcher" screen. `extraTiles`
/// lets a screen mix in one-off cards that don't fit the plain-link pattern
/// (e.g. a card that navigates in-app instead of opening a browser).
class PortalCategoryListView extends StatelessWidget {
  final List<PortalCategory> categories;
  final List<Widget> extraTiles;
  const PortalCategoryListView({
    super.key,
    required this.categories,
    this.extraTiles = const [],
  });

  @override
  Widget build(BuildContext context) {
    final links = [for (final category in categories) ...category.links];
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        if (isMobile) {
          final crossAxisCount = constraints.maxWidth < 360 ? 1 : 2;
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: crossAxisCount == 1 ? 2.2 : 0.95,
            ),
            itemCount: links.length + extraTiles.length,
            itemBuilder: (context, index) {
              if (index < links.length) {
                final link = links[index];
                return PortalCardTile(
                  name: link.name,
                  icon: link.icon,
                  color: link.color,
                  imageUrl: link.imageUrl,
                  onTap: () => launchGatedPortalLink(context, link),
                );
              }
              return extraTiles[index - links.length];
            },
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            children: [
              for (final link in links)
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
              ...extraTiles,
            ],
          ),
        );
      },
    );
  }
}

class PortalCardTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String caption;
  final String? imageUrl;
  const PortalCardTile({
    super.key,
    required this.name,
    required this.icon,
    required this.color,
    required this.onTap,
    this.caption = 'Open in Browser',
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfacePanel,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.12),
        hoverColor: color.withValues(alpha: 0.06),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.lineHairline, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 3.5, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: imageUrl == null
                                ? Icon(icon, color: color, size: 22)
                                : Image.network(
                                    imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Icon(icon, color: color, size: 22),
                                  ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.arrow_outward_rounded, size: 14, color: color),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              color: AppColors.inkPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            caption,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
