import 'package:flutter/material.dart';

import '../constants/enums.dart';

/// One icon per enum value, shared by every screen.
///
/// Kept beside the colours rather than inside a widget so a phone call looks
/// the same on the contact card, the schedule form and the activity list.
abstract final class AppIcons {
  static IconData forContactMethod(ContactMethod method) => switch (method) {
        ContactMethod.phone => Icons.call,
        ContactMethod.whatsapp => Icons.chat_outlined,
        ContactMethod.viber => Icons.forum_outlined,
        ContactMethod.email => Icons.mail_outline,
        ContactMethod.inPerson => Icons.handshake_outlined,
      };

  static IconData forActivityType(ActivityType type) => switch (type) {
        ActivityType.phoneCall => Icons.call,
        ActivityType.inPersonMeeting => Icons.handshake_outlined,
        ActivityType.onlineMeeting => Icons.videocam_outlined,
        ActivityType.venueVisit => Icons.stadium_outlined,
        ActivityType.followUp => Icons.update,
        ActivityType.other => Icons.event_note_outlined,
      };
}
