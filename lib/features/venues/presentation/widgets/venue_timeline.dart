import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/entities/timeline_entry.dart';

/// The venue's history as a vertical timeline.
///
/// Ordered by time with the most recent first — but an activity that has not
/// happened yet sits on the timeline at its scheduled slot, which is in the
/// future. Mixed into the same list it would outrank everything that actually
/// happened, so the two are split: what is coming up, then the history.
class VenueTimeline extends StatelessWidget {
  const VenueTimeline({super.key, required this.entries});

  /// Already newest-first, as `TimelineEntry.merge` returns them.
  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = entries.where((e) => e.isUpcoming(now: now)).toList();
    final past = entries.where((e) => !e.isUpcoming(now: now)).toList();

    // Soonest first while it is still ahead of us: the next thing due is the
    // one that matters, not the one furthest away.
    final scheduled = upcoming.reversed.toList();

    final rows = <Widget>[
      if (scheduled.isNotEmpty) ...[
        const _TimelineHeading(label: 'Upcoming', icon: Icons.schedule),
        for (var i = 0; i < scheduled.length; i++)
          _TimelineTile(
            entry: scheduled[i],
            isLast: i == scheduled.length - 1,
            dimmed: true,
          ),
      ],
      if (past.isNotEmpty) ...[
        if (scheduled.isNotEmpty)
          const _TimelineHeading(label: 'History', icon: Icons.history),
        for (var i = 0; i < past.length; i++)
          _TimelineTile(entry: past[i], isLast: i == past.length - 1),
      ],
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index],
    );
  }
}

/// Separates the two halves of the list.
class _TimelineHeading extends StatelessWidget {
  const _TimelineHeading({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 7),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1, color: AppColors.outline)),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.entry,
    required this.isLast,
    this.dimmed = false,
  });

  final TimelineEntry entry;
  final bool isLast;

  /// Something that has not happened yet: drawn as an outline so it does not
  /// read as a record of anything.
  final bool dimmed;

  ({IconData icon, Color color}) get _marker => switch (entry.kind) {
        TimelineKind.note => (icon: Icons.sticky_note_2_outlined, color: AppColors.info),
        TimelineKind.statusChange => (
            icon: Icons.swap_horiz,
            color: entry.newStatus == null
                ? AppColors.primary
                : AppColors.forLeadStatus(entry.newStatus!),
          ),
        TimelineKind.activity => (
            icon: entry.activityType == null
                ? Icons.event_note_outlined
                : AppIcons.forActivityType(entry.activityType!),
            color: AppColors.primary,
          ),
        TimelineKind.visit => (
            icon: Icons.where_to_vote_outlined,
            color: AppColors.secondary,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final marker = _marker;

    return Stack(
      children: [
        // The connector is drawn behind the row rather than sized by it.
        // IntrinsicHeight would otherwise force a second layout pass on every
        // tile, which is exactly the wrong thing inside a scrolling list.
        if (!isLast)
          Positioned(
            left: 14,
            top: 30,
            bottom: 0,
            child: Container(width: 2, color: AppColors.outline),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: dimmed
                    ? AppColors.surface
                    : marker.color.withValues(alpha: 0.13),
                shape: BoxShape.circle,
                border: dimmed
                    ? Border.all(color: marker.color.withValues(alpha: 0.45))
                    : null,
              ),
              child: Icon(marker.icon, size: 16, color: marker.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '${AppDateUtils.formatDateTime(entry.occurredAt)}'
                        ' · ${AppDateUtils.relativeLabel(entry.occurredAt)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (entry.actorName.trim().isNotEmpty) ...[
                        const Text(
                          ' · ',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                        ),
                        Flexible(
                          child: Text(
                            entry.actorName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (entry.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        entry.body,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                  if (entry.isSelfReported != null || entry.wasEdited) ...[
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      children: [
                        // Says plainly how a visit was evidenced, rather than
                        // implying the app verified the employee was there.
                        if (entry.isSelfReported != null)
                          StatusChip(
                            label: entry.isSelfReported!
                                ? 'Self-reported'
                                : 'Location-supported',
                            color: entry.isSelfReported!
                                ? AppColors.textMuted
                                : AppColors.secondary,
                            icon: entry.isSelfReported!
                                ? Icons.person_outline
                                : Icons.my_location,
                            dense: true,
                          ),
                        if (entry.wasEdited)
                          const StatusChip(
                            label: 'Edited',
                            color: AppColors.textMuted,
                            icon: Icons.edit_outlined,
                            dense: true,
                          ),
                      ],
                    ),
                  ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
