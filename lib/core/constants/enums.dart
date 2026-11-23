// Domain enumerations.
//
// Every enum stores the exact string persisted in Firestore alongside a
// human label, and every one parses unknown values to a safe fallback so that
// a document written by a newer build never crashes an older client.

enum UserRole {
  admin('admin', 'Admin'),
  employee('employee', 'Employee');

  const UserRole(this.value, this.label);
  final String value;
  final String label;

  static UserRole fromValue(String? value) =>
      UserRole.values.firstWhere((r) => r.value == value, orElse: () => UserRole.employee);

  bool get isAdmin => this == UserRole.admin;
}

enum UserStatus {
  active('active', 'Active'),
  disabled('disabled', 'Disabled');

  const UserStatus(this.value, this.label);
  final String value;
  final String label;

  static UserStatus fromValue(String? value) =>
      UserStatus.values.firstWhere((s) => s.value == value, orElse: () => UserStatus.active);

  bool get isActive => this == UserStatus.active;
}

enum ProjectStatus {
  active('active', 'Active'),
  paused('paused', 'Paused'),
  completed('completed', 'Completed'),
  archived('archived', 'Archived');

  const ProjectStatus(this.value, this.label);
  final String value;
  final String label;

  static ProjectStatus fromValue(String? value) =>
      ProjectStatus.values.firstWhere((s) => s.value == value, orElse: () => ProjectStatus.active);

  bool get isOpen => this == ProjectStatus.active || this == ProjectStatus.paused;
}

/// The eleven lead states from the workflow spec, in pipeline order.
enum LeadStatus {
  newLead('new', 'New'),
  contacted('contacted', 'Contacted'),
  interested('interested', 'Interested'),
  meetingScheduled('meeting_scheduled', 'Meeting Scheduled'),
  visited('visited', 'Visited'),
  negotiation('negotiation', 'Negotiation'),
  converted('converted', 'Converted'),
  followUpRequired('follow_up_required', 'Follow-up Required'),
  notInterested('not_interested', 'Not Interested'),
  unresponsive('unresponsive', 'Unresponsive'),
  onHold('on_hold', 'On Hold');

  const LeadStatus(this.value, this.label);
  final String value;
  final String label;

  static LeadStatus fromValue(String? value) =>
      LeadStatus.values.firstWhere((s) => s.value == value, orElse: () => LeadStatus.newLead);

  /// Terminal states no longer need follow-up chasing.
  bool get isClosed => this == LeadStatus.converted || this == LeadStatus.notInterested;

  bool get isWon => this == LeadStatus.converted;
}

enum VenuePriority {
  high('high', 'High', 0),
  medium('medium', 'Medium', 1),
  low('low', 'Low', 2);

  const VenuePriority(this.value, this.label, this.sortOrder);
  final String value;
  final String label;

  /// Ascending sort puts High first, which is what every "next up" list wants.
  final int sortOrder;

  static VenuePriority fromValue(String? value) =>
      VenuePriority.values.firstWhere((p) => p.value == value, orElse: () => VenuePriority.medium);
}

enum VenueType {
  indoor('indoor', 'Indoor'),
  outdoor('outdoor', 'Outdoor'),
  rooftop('rooftop', 'Rooftop'),
  mixed('mixed', 'Mixed'),
  other('other', 'Other');

  const VenueType(this.value, this.label);
  final String value;
  final String label;

  static VenueType fromValue(String? value) =>
      VenueType.values.firstWhere((t) => t.value == value, orElse: () => VenueType.other);
}

enum LeadSource {
  fieldVisit('field_visit', 'Field Visit'),
  referral('referral', 'Referral'),
  phoneInquiry('phone_inquiry', 'Phone Inquiry'),
  socialMedia('social_media', 'Social Media'),
  website('website', 'Website'),
  walkIn('walk_in', 'Walk-in'),
  other('other', 'Other');

  const LeadSource(this.value, this.label);
  final String value;
  final String label;

  static LeadSource fromValue(String? value) =>
      LeadSource.values.firstWhere((s) => s.value == value, orElse: () => LeadSource.other);
}

enum ContactMethod {
  phone('phone', 'Phone Call'),
  whatsapp('whatsapp', 'WhatsApp'),
  viber('viber', 'Viber'),
  email('email', 'Email'),
  inPerson('in_person', 'In Person');

  const ContactMethod(this.value, this.label);
  final String value;
  final String label;

  static ContactMethod fromValue(String? value) =>
      ContactMethod.values.firstWhere((m) => m.value == value, orElse: () => ContactMethod.phone);
}

enum ActivityType {
  phoneCall('phone_call', 'Phone Call'),
  inPersonMeeting('in_person_meeting', 'In-Person Meeting'),
  onlineMeeting('online_meeting', 'Online Meeting'),
  venueVisit('venue_visit', 'Venue Visit'),
  followUp('follow_up', 'Follow-Up'),
  other('other', 'Other');

  const ActivityType(this.value, this.label);
  final String value;
  final String label;

  static ActivityType fromValue(String? value) =>
      ActivityType.values.firstWhere((t) => t.value == value, orElse: () => ActivityType.other);
}

enum ActivityStatus {
  scheduled('scheduled', 'Scheduled'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled'),
  rescheduled('rescheduled', 'Rescheduled'),
  missed('missed', 'Missed');

  const ActivityStatus(this.value, this.label);
  final String value;
  final String label;

  static ActivityStatus fromValue(String? value) => ActivityStatus.values
      .firstWhere((s) => s.value == value, orElse: () => ActivityStatus.scheduled);

  /// Only a still-open activity can fall overdue.
  bool get isOpen => this == ActivityStatus.scheduled || this == ActivityStatus.rescheduled;
}

enum VisitStatus {
  planned('planned', 'Planned'),
  inProgress('in_progress', 'In Progress'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  const VisitStatus(this.value, this.label);
  final String value;
  final String label;

  static VisitStatus fromValue(String? value) =>
      VisitStatus.values.firstWhere((s) => s.value == value, orElse: () => VisitStatus.planned);
}
