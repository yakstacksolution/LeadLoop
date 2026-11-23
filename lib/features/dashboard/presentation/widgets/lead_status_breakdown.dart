import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/dashboard_stats.dart';

/// Horizontal bars showing how venues are spread across the lead pipeline.
///
/// A bar chart rather than a pie: eleven categories are unreadable as wedges,
/// and the numbers matter more than the proportions here.
class LeadStatusBreakdown extends StatelessWidget {
  const LeadStatusBreakdown({super.key, required this.stats, this.onStatusTap});

  final DashboardStats stats;
  final void Function(LeadStatus status)? onStatusTap;

  @override
  Widget build(BuildContext context) {
    final entries = LeadStatus.values
        .map((status) => (status: status, count: stats.countOf(status)))
        .where((entry) => entry.count > 0)
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No venues yet. Lead statuses will appear here once venues are added.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
      );
    }

    final max = entries.first.count;

    return Column(
      children: [
        for (final entry in entries)
          _StatusBar(
            status: entry.status,
            count: entry.count,
            fraction: max == 0 ? 0 : entry.count / max,
            total: stats.totalVenues,
            onTap: onStatusTap == null ? null : () => onStatusTap!(entry.status),
          ),
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.status,
    required this.count,
    required this.fraction,
    required this.total,
    this.onTap,
  });

  final LeadStatus status;
  final int count;
  final double fraction;
  final int total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forLeadStatus(status);
    final share = total == 0 ? 0 : (count / total * 100).round();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    status.label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 38,
                  child: Text(
                    '$share%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: AppColors.surfaceMuted,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
