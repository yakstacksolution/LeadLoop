import 'package:flutter/material.dart';

import '../../domain/entities/customer.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final CustomerStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(_label),
      visualDensity: VisualDensity.compact,
      backgroundColor: _color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: _color, fontWeight: FontWeight.w800),
    );
  }

  String get _label {
    return switch (status) {
      CustomerStatus.newLead => 'New',
      CustomerStatus.contacted => 'Contacted',
      CustomerStatus.interested => 'Interested',
      CustomerStatus.demoScheduled => 'Demo',
      CustomerStatus.negotiating => 'Negotiating',
      CustomerStatus.converted => 'Converted',
      CustomerStatus.notInterested => 'Not interested',
      CustomerStatus.lost => 'Lost',
    };
  }

  Color get _color {
    return switch (status) {
      CustomerStatus.converted => const Color(0xFF148A42),
      CustomerStatus.lost ||
      CustomerStatus.notInterested => const Color(0xFFB42318),
      CustomerStatus.demoScheduled ||
      CustomerStatus.negotiating => const Color(0xFF7A4E00),
      _ => const Color(0xFF00897B),
    };
  }
}
