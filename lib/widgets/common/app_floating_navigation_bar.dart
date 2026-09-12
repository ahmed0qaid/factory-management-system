import 'package:flutter/material.dart';

import '../../theme/app_icon_sizes.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class AppFloatingNavigationItem {
  final Widget icon;
  final Widget selectedIcon;
  final String label;

  const AppFloatingNavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class AppFloatingNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final List<AppFloatingNavigationItem> items;
  final ValueChanged<int> onDestinationSelected;

  const AppFloatingNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onDestinationSelected,
  });

  static const double _height = 78;
  static const double _indicatorSize = 52;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final safeIndex = selectedIndex.clamp(0, items.length - 1).toInt();
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: SizedBox(
          height: _height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / items.length;
              final visualSlot =
                  isRtl ? items.length - 1 - safeIndex : safeIndex;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    top: AppSpacing.sm,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.xl),
                        ),
                        border: Border(
                          top: BorderSide(color: scheme.outlineVariant),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.shadow.withValues(alpha: .08),
                            blurRadius: AppSpacing.md,
                            offset: const Offset(0, -AppSpacing.xxs),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          for (var index = 0; index < items.length; index++)
                            Expanded(
                              child: _NavigationDestination(
                                item: items[index],
                                selected: index == safeIndex,
                                onTap: () => onDestinationSelected(index),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    top: 0,
                    left: visualSlot * itemWidth,
                    width: itemWidth,
                    height: _indicatorSize,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          width: _indicatorSize,
                          height: _indicatorSize,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: scheme.surface,
                              width: AppSpacing.xxs - 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: .28),
                                blurRadius: AppSpacing.md,
                                offset: const Offset(0, AppSpacing.xs),
                              ),
                            ],
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                scale: animation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              ),
                              child: IconTheme(
                                key: ValueKey(safeIndex),
                                data: IconThemeData(
                                  color: scheme.onPrimary,
                                  size: AppIconSizes.navigation,
                                ),
                                child: items[safeIndex].selectedIcon,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavigationDestination extends StatelessWidget {
  final AppFloatingNavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavigationDestination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.xxs,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: AppSpacing.xxl,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: selected ? 0 : 1,
                  child: IconTheme(
                    data: IconThemeData(
                      color: scheme.onSurfaceVariant,
                      size: AppIconSizes.standard,
                    ),
                    child: item.icon,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
