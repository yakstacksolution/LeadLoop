// SectionHeading is shared with the forms, so the dashboard re-exports it
// rather than keeping a second copy.
export '../../../../shared/widgets/choice_chips.dart' show SectionHeading;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../../../shared/widgets/state_views.dart';

/// Greeting banner at the top of the admin Overview.
///
/// Carries the three numbers that answer "how is the pipeline doing?" without
/// scrolling — total venues, live pipeline, conversion rate — on a brand
/// gradient so the rest of the page can stay quiet and white.
class OverviewHeader extends StatelessWidget {
  const OverviewHeader({super.key, required this.stats, this.name});

  final DashboardStats stats;
  final String? name;

  /// Time-of-day greeting. Field staff open this at dawn and after dark, so a
  /// static "Welcome" would read oddly.
  static String greetingFor(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final rate = stats.conversionRate;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            OverviewHeader.greetingFor(DateTime.now()),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            name ?? 'Overview',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeaderMetric(
                label: 'Venues',
                value: '${stats.totalVenues}',
              ),
              const _HeaderDivider(),
              _HeaderMetric(
                label: 'In pipeline',
                value: '${stats.inPipeline}',
              ),
              const _HeaderDivider(),
              _HeaderMetric(
                label: 'Converted',
                value: rate == null ? '—' : '${rate.round()}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _HeaderDivider extends StatelessWidget {
  const _HeaderDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white24,
    );
  }
}

/// Amber/red strip shown only when something has actually slipped.
///
/// Deliberately absent on a clean day: a banner that is always there stops
/// being read.
class AttentionBanner extends StatelessWidget {
  const AttentionBanner({
    super.key,
    required this.overdue,
    required this.dueToday,
    required this.onTap,
  });

  final int overdue;
  final int dueToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = overdue > 0 ? AppColors.danger : AppColors.warning;
    final message = overdue > 0
        ? '$overdue follow-up${overdue == 1 ? '' : 's'} overdue'
        : '$dueToday follow-up${dueToday == 1 ? '' : 's'} due today';
    final detail = overdue > 0 && dueToday > 0
        ? '$dueToday more due today'
        : 'Tap to open the activity list';

    return Material(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(
                overdue > 0
                    ? Icons.warning_amber_rounded
                    : Icons.today_outlined,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder blocks shown while the first load is in flight.
///
/// Keeps the page's shape stable so content does not jump in, which reads as
/// faster than a centred spinner even though it is not.
class OverviewSkeleton extends StatelessWidget {
  const OverviewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: const [
        SkeletonBlock(height: 132, radius: 18),
        SizedBox(height: 20),
        SkeletonBlock(height: 96),
        SizedBox(height: 20),
        SkeletonBlock(height: 108),
        SizedBox(height: 12),
        SkeletonBlock(height: 108),
        SizedBox(height: 20),
        SkeletonBlock(height: 160),
      ],
    );
  }
}
