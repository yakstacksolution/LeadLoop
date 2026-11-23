import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_colors.dart';

class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badgeCount,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Optional unread/overdue count drawn on the icon. Null (or zero) hides it.
  final int? badgeCount;
}

/// Publishes which shell branch is currently showing.
///
/// `StatefulNavigationShell.of` finds the shell by ancestor lookup, which
/// creates no dependency — a page inside a branch is never rebuilt when the
/// selected tab changes. This is: branch content depends on it, so returning
/// to a tab rebuilds what is listening. [BranchRefresh] is what uses it.
class ActiveBranch extends InheritedWidget {
  const ActiveBranch({super.key, required this.index, required super.child});

  final int index;

  static int? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ActiveBranch>()
      ?.index;

  @override
  bool updateShouldNotify(ActiveBranch oldWidget) => index != oldWidget.index;
}

/// Runs [onReturn] whenever its own branch becomes the selected one again.
///
/// Branches live in an IndexedStack and keep their state, so a list built on
/// a one-shot query would still be showing whatever it fetched the first time
/// the tab was opened. This re-fetches on the way back in.
class BranchRefresh extends StatefulWidget {
  const BranchRefresh({super.key, required this.onReturn, required this.child});

  final VoidCallback onReturn;
  final Widget child;

  @override
  State<BranchRefresh> createState() => _BranchRefreshState();
}

class _BranchRefreshState extends State<BranchRefresh> {
  /// The branch this widget lives in: whichever one was selected when it was
  /// first built, since a branch is only built once it is shown.
  int? _ownIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final active = ActiveBranch.maybeOf(context);
    if (active == null) return;

    if (_ownIndex == null) {
      _ownIndex = active;
      return;
    }

    if (active == _ownIndex) {
      // Dependencies settle during build, so the refresh is deferred rather
      // than emitting a new state mid-frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onReturn();
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Adaptive navigation chrome.
///
/// A bottom bar on phones, where field staff work one-handed, and a rail on
/// anything wider, so an admin on a laptop is not left with a phone layout in
/// a maximised window.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.destinations,
  });

  final StatefulNavigationShell navigationShell;
  final List<ShellDestination> destinations;

  void _goToBranch(int index) {
    // A light tick confirms the tap on phones where the visual change is the
    // only other feedback.
    HapticFeedback.selectionClick();
    navigationShell.goBranch(
      index,
      // Tapping the current tab again pops back to that branch's first screen,
      // which is the behaviour people expect from a bottom bar.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _goToBranch,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Icon(Icons.sports_soccer, color: AppColors.primary, size: 28),
              ),
              destinations: [
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: _DestinationIcon(
                      icon: destination.icon,
                      badgeCount: destination.badgeCount,
                      color: AppColors.textSecondary,
                    ),
                    selectedIcon: _DestinationIcon(
                      icon: destination.selectedIcon,
                      badgeCount: destination.badgeCount,
                      color: AppColors.primary,
                    ),
                    label: Text(destination.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: ActiveBranch(
                index: navigationShell.currentIndex,
                child: navigationShell,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: ActiveBranch(
        index: navigationShell.currentIndex,
        child: navigationShell,
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
        destinations: destinations,
        onSelected: _goToBranch,
      ),
    );
  }
}

/// The phone navigation bar.
///
/// Hand-rolled rather than `NavigationBar` so the selected pill, label weight
/// and badges can be tuned together: with five destinations on a 360dp screen
/// the stock bar clips labels, and its indicator is wider than the space each
/// tab actually gets.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.onSelected,
  });

  final int currentIndex;
  final List<ShellDestination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    selected: i == currentIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkResponse(
        onTap: onTap,
        radius: 42,
        highlightShape: BoxShape.rectangle,
        containedInkWell: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 44,
              height: 28,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: _DestinationIcon(
                icon: selected ? destination.selectedIcon : destination.icon,
                badgeCount: destination.badgeCount,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 11,
                height: 1.1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An icon with an optional count badge pinned to its top-right.
class _DestinationIcon extends StatelessWidget {
  const _DestinationIcon({
    required this.icon,
    required this.color,
    this.badgeCount,
    this.size = 24,
  });

  final IconData icon;
  final Color color;
  final int? badgeCount;
  final double size;

  @override
  Widget build(BuildContext context) {
    final count = badgeCount ?? 0;
    final iconWidget = Icon(icon, size: size, color: color);
    if (count <= 0) return iconWidget;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        Positioned(
          top: -5,
          right: -8,
          child: Container(
            constraints: const BoxConstraints(minWidth: 16),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surface, width: 1.5),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9.5,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
