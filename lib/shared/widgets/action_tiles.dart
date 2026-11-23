import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// One tappable action: icon, label, colour.
class AppAction {
  const AppAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = AppColors.primary,
    this.badge,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  /// Optional short caption under the label, e.g. "Due in 2 days".
  final String? badge;
  final bool enabled;
}

/// A responsive grid of large, thumb-friendly action tiles.
///
/// Shared by the dashboards and the venue detail screen so the primary actions
/// look and behave identically wherever they appear. Sized generously on
/// purpose: these are tapped outdoors, often one-handed.
class ActionTileGrid extends StatelessWidget {
  const ActionTileGrid({
    super.key,
    required this.actions,
    this.minTileWidth = 150,
  });

  final List<AppAction> actions;

  /// Below this width the grid drops to two columns.
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final maxColumns = actions.length.clamp(1, 4);
        final columns = constraints.maxWidth >= minTileWidth * maxColumns
            ? maxColumns
            : 2;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final action in actions)
              SizedBox(width: width, child: _ActionTile(action: action)),
          ],
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final AppAction action;

  @override
  Widget build(BuildContext context) {
    final color = action.enabled ? action.color : AppColors.textMuted;

    return Material(
      color: color.withValues(alpha: action.enabled ? 0.10 : 0.06),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: action.enabled ? action.onTap : null,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(action.icon, size: 20, color: color),
              ),
              const SizedBox(height: 9),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                  height: 1.2,
                ),
              ),
              if (action.badge != null) ...[
                const SizedBox(height: 3),
                Text(
                  action.badge!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                    height: 1.1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
