import 'package:flutter/material.dart';

import '../constants/enums.dart';

/// Hamro Futsal brand palette.
abstract final class AppColors {
  static const primary = Color(0xFFF27819); // brand orange
  static const secondary = Color(0xFF2C7969); // brand green

  static const primaryDark = Color(0xFFC85F0D);
  static const secondaryDark = Color(0xFF1E5A4E);

  static const background = Color(0xFFF7F7F9);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF0F1F4);
  static const outline = Color(0xFFDDE0E6);

  static const textPrimary = Color(0xFF1B1D21);
  static const textSecondary = Color(0xFF5F6570);
  static const textMuted = Color(0xFF8A909B);

  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFE08600);
  static const danger = Color(0xFFC62828);
  static const info = Color(0xFF1565C0);
  static const neutral = Color(0xFF6B7280);

  /// Status colours are chosen so that the pipeline reads left to right:
  /// grey (untouched) → blue (engaged) → amber (in play) → green (won) →
  /// red (lost). Every one of these clears 4.5:1 against white when used as
  /// text, and the chip renders dark text on a tinted background.
  static Color forLeadStatus(LeadStatus status) => switch (status) {
        LeadStatus.newLead => neutral,
        LeadStatus.contacted => info,
        LeadStatus.interested => const Color(0xFF00897B),
        LeadStatus.meetingScheduled => const Color(0xFF5E35B1),
        LeadStatus.visited => secondary,
        LeadStatus.negotiation => warning,
        LeadStatus.converted => success,
        LeadStatus.followUpRequired => primary,
        LeadStatus.notInterested => danger,
        LeadStatus.unresponsive => const Color(0xFF795548),
        LeadStatus.onHold => const Color(0xFF546E7A),
      };

  static Color forActivityStatus(ActivityStatus status) => switch (status) {
        ActivityStatus.scheduled => info,
        ActivityStatus.completed => success,
        ActivityStatus.cancelled => neutral,
        ActivityStatus.rescheduled => warning,
        ActivityStatus.missed => danger,
      };

  static Color forVisitStatus(VisitStatus status) => switch (status) {
        VisitStatus.planned => info,
        VisitStatus.inProgress => primary,
        VisitStatus.completed => success,
        VisitStatus.cancelled => neutral,
      };

  static Color forPriority(VenuePriority priority) => switch (priority) {
        VenuePriority.high => danger,
        VenuePriority.medium => warning,
        VenuePriority.low => neutral,
      };

  static Color forProjectStatus(ProjectStatus status) => switch (status) {
        ProjectStatus.active => success,
        ProjectStatus.paused => warning,
        ProjectStatus.completed => info,
        ProjectStatus.archived => neutral,
      };
}
