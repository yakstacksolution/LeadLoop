import 'package:cloud_firestore/cloud_firestore.dart';

/// Defensive readers for Firestore documents.
///
/// A document may predate a field, or have been written by a newer build, so
/// every read is total: it returns a sensible default instead of throwing. A
/// malformed record should degrade one field, never crash a whole list.
abstract final class Read {
  static String string(Map<String, dynamic> data, String key, [String fallback = '']) {
    final value = data[key];
    return value is String ? value : fallback;
  }

  static String? stringOrNull(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String) return null;
    return value.isEmpty ? null : value;
  }

  static int intValue(Map<String, dynamic> data, String key, [int fallback = 0]) {
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static int? intOrNull(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? doubleOrNull(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool boolValue(Map<String, dynamic> data, String key, [bool fallback = false]) {
    final value = data[key];
    return value is bool ? value : fallback;
  }

  static List<String> stringList(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }

  /// Converts a Firestore `Timestamp` to a local `DateTime`.
  ///
  /// Also tolerates an ISO string or epoch millis, which is what the emulator
  /// seed scripts and any hand-edited document tend to contain.
  static DateTime? dateTime(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// A geo point stored either as a `GeoPoint` or as a `{lat, lng}` map.
  static ({double latitude, double longitude})? geoPoint(
    Map<String, dynamic> data,
    String key,
  ) {
    final value = data[key];
    if (value is GeoPoint) {
      return (latitude: value.latitude, longitude: value.longitude);
    }
    if (value is Map) {
      final lat = value['latitude'] ?? value['lat'];
      final lng = value['longitude'] ?? value['lng'];
      if (lat is num && lng is num) {
        return (latitude: lat.toDouble(), longitude: lng.toDouble());
      }
    }
    return null;
  }
}

/// Shorthand for the server-side clock. Client clocks are never trusted for
/// ordering, and the security rules require exactly this value on create.
FieldValue get serverTime => FieldValue.serverTimestamp();

/// Converts a nullable `DateTime` into a Firestore-safe value.
Timestamp? toTimestamp(DateTime? value) =>
    value == null ? null : Timestamp.fromDate(value);
