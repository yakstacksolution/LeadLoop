import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// The app's one floating action button.
///
/// Deliberately the same object as every other primary button on screen: the
/// brand orange, the 12px radius and the 15/w600 label all come from
/// `filledButtonTheme`, so a FAB and a "Save changes" button read as the same
/// control in two places rather than two different systems.
///
/// Built by hand rather than with `FloatingActionButton.extended` for two
/// reasons: a mandatory [heroTag] — shell branches live in an IndexedStack,
/// so several FABs are mounted at once and the default shared tag throws —
/// and a [busy] state, since most of these buttons start a write.
class AppFab extends StatelessWidget {
  const AppFab({
    super.key,
    required this.heroTag,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    this.extended = true,
  });

  /// Unique within any one route subtree. Conventionally `fab-<screen>`.
  final String heroTag;

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Swaps the icon for a spinner and blocks taps.
  final bool busy;

  /// False renders an icon-only square button, for screens where the label
  /// would cover content.
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null && !busy;
    final radius = BorderRadius.circular(12);
    final color = theme.colorScheme.primary;

    return Hero(
      tag: heroTag,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: Material(
          color: enabled ? color : color.withValues(alpha: 0.55),
          borderRadius: radius,
          elevation: 3,
          shadowColor: AppColors.textPrimary.withValues(alpha: 0.35),
          child: InkWell(
            borderRadius: radius,
            onTap: enabled
                ? () {
                    HapticFeedback.lightImpact();
                    onPressed!();
                  }
                : null,
            child: Container(
              height: 50,
              constraints: BoxConstraints(minWidth: extended ? 0 : 50),
              padding: EdgeInsets.symmetric(horizontal: extended ? 18 : 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    const SizedBox(
                      height: 19,
                      width: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  else
                    Icon(icon, size: 20, color: Colors.white),
                  if (extended && !busy) ...[
                    const SizedBox(width: 9),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
