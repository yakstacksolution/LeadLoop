class TimelineEntry {
  const TimelineEntry({
    required this.id,
    required this.customerId,
    required this.title,
    required this.note,
    required this.authorName,
    required this.createdAt,
  });

  final String id;
  final String customerId;
  final String title;
  final String note;
  final String authorName;
  final DateTime createdAt;
}
