enum ContactMethod { call, whatsApp, email, visit, meeting, other }

enum FollowUpOutcome {
  connected,
  noAnswer,
  busy,
  callbackRequested,
  demoBooked,
  demoCompleted,
  wrongNumber,
  other,
}

class FollowUpTask {
  const FollowUpTask({
    required this.id,
    required this.customerId,
    required this.productId,
    required this.assignedUserId,
    required this.dueAt,
    required this.nextAction,
    required this.isOpen,
  });

  final String id;
  final String customerId;
  final String productId;
  final String assignedUserId;
  final DateTime dueAt;
  final String nextAction;
  final bool isOpen;

  bool get isOverdue => dueAt.isBefore(DateTime.now());
}
