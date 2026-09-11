enum LeadSource { phone, website, referral, socialMedia, visit, other }

enum Priority { low, normal, high }

enum CustomerStatus {
  newLead,
  contacted,
  interested,
  demoScheduled,
  negotiating,
  converted,
  notInterested,
  lost,
}

class Venue {
  const Venue({
    required this.name,
    required this.address,
    required this.contactPerson,
    required this.phoneNumber,
  });

  final String name;
  final String address;
  final String contactPerson;
  final String phoneNumber;
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.businessName,
    required this.productId,
    required this.phoneNumber,
    required this.email,
    required this.address,
    required this.venues,
    required this.assignedUserId,
    required this.leadSource,
    required this.priority,
    required this.status,
    required this.description,
    required this.lastContactedAt,
    required this.nextFollowUpAt,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String businessName;
  final String productId;
  final String phoneNumber;
  final String email;
  final String address;
  final List<Venue> venues;
  final String assignedUserId;
  final LeadSource leadSource;
  final Priority priority;
  final CustomerStatus status;
  final String description;
  final DateTime? lastContactedAt;
  final DateTime? nextFollowUpAt;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOverdue {
    final next = nextFollowUpAt;
    return next != null && next.isBefore(DateTime.now());
  }

  bool get isDueToday {
    final next = nextFollowUpAt;
    if (next == null) return false;
    final now = DateTime.now();
    return next.year == now.year &&
        next.month == now.month &&
        next.day == now.day;
  }
}
