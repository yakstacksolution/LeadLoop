import 'package:flutter/material.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';

/// Centred spinner for a whole screen or panel.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2.5),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// Shown when a query legitimately returned nothing.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      // Scrolls instead of overflowing when a keyboard leaves little room.
      child: SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when something failed. Always offers a retry — a dead end with no way
/// forward is the one thing a field user cannot work around.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.failure, this.onRetry});

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isPermission = failure is PermissionFailure;

    return Center(
      // Scrolls instead of overflowing when a keyboard leaves little room.
      child: SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPermission ? Icons.lock_outline : Icons.error_outline,
              size: 52,
              color: isPermission ? AppColors.warning : AppColors.danger,
            ),
            const SizedBox(height: 16),
            Text(
              isPermission ? 'Not allowed' : 'Something went wrong',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              failure.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single-line banner for a non-blocking problem above otherwise usable
/// content.
class InlineMessage extends StatelessWidget {
  const InlineMessage({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.color = AppColors.info,
    this.onDismiss,
  });

  const InlineMessage.warning({super.key, required this.message, this.onDismiss})
      : icon = Icons.warning_amber_rounded,
        color = AppColors.warning;

  const InlineMessage.error({super.key, required this.message, this.onDismiss})
      : icon = Icons.error_outline,
        color = AppColors.danger;

  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13, height: 1.35),
            ),
          ),
          if (onDismiss != null)
            InkWell(
              onTap: onDismiss,
              child: Icon(Icons.close, size: 16, color: color),
            ),
        ],
      ),
    );
  }
}

/// Fades its child in once, when it first appears.
///
/// Wraps content that replaces a loading state, so it does not pop in. Later
/// rebuilds do not replay it.
class FadeIn extends StatefulWidget {
  const FadeIn({super.key, required this.child});

  final Widget child;

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _opacity =
      _controller.drive(CurveTween(curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}

/// A placeholder block for content that is still loading.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({super.key, required this.height, this.radius = 14});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Card-shaped placeholders for a list's first load, so the page keeps its
/// shape when the real cards arrive.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.itemHeight = 104,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  final double itemHeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ListView.separated(
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        itemCount: 8,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => SkeletonBlock(height: itemHeight),
      ),
    );
  }
}
