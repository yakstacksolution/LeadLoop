import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// One search hit: a human-readable place with coordinates.
class PlaceResult {
  const PlaceResult({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  /// First component of the address — usually the venue or street name.
  final String title;

  /// The rest of the address, shown smaller under the title.
  final String subtitle;

  final double latitude;
  final double longitude;

  String get fullAddress =>
      subtitle.isEmpty ? title : '$title, $subtitle';
}

/// Place search and reverse geocoding backed by OpenStreetMap's Nominatim.
///
/// Chosen over the Google Places API because it needs no key or billing
/// account, which keeps the app buildable by anyone on the team. Nominatim's
/// usage policy caps this at roughly one request a second and requires an
/// identifying User-Agent, so callers must debounce — [searchDebounce] is the
/// interval the UI uses.
class PlaceSearchService {
  const PlaceSearchService({this.client});

  final http.Client? client;

  static const searchDebounce = Duration(milliseconds: 450);

  static const _host = 'nominatim.openstreetmap.org';
  static const _headers = {
    'User-Agent': 'HamroFutsalLeadApp/1.0 (internal venue tool)',
    'Accept': 'application/json',
  };

  /// Free-text search. Returns an empty list on any failure — a lookup that
  /// quietly finds nothing is better here than an error dialog over the map.
  Future<List<PlaceResult>> search(String query, {int limit = 8}) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];

    final uri = Uri.https(_host, '/search', {
      'q': trimmed,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '$limit',
      'accept-language': 'en',
    });

    final body = await _get(uri);
    if (body is! List) return const [];

    return body
        .whereType<Map<String, dynamic>>()
        .map(_toResult)
        .nonNulls
        .toList(growable: false);
  }

  /// The address at a point, used to label a pin the user dropped by hand.
  /// Null when the lookup fails or the point is in the middle of nowhere.
  Future<PlaceResult?> reverse(double latitude, double longitude) async {
    final uri = Uri.https(_host, '/reverse', {
      'lat': '$latitude',
      'lon': '$longitude',
      'format': 'jsonv2',
      'addressdetails': '1',
      'accept-language': 'en',
    });

    final body = await _get(uri);
    if (body is! Map<String, dynamic>) return null;
    return _toResult(body);
  }

  Future<Object?> _get(Uri uri) async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static PlaceResult? _toResult(Map<String, dynamic> json) {
    final lat = double.tryParse('${json['lat']}');
    final lon = double.tryParse('${json['lon']}');
    if (lat == null || lon == null) return null;

    final display = '${json['display_name'] ?? ''}'.trim();
    if (display.isEmpty) return null;

    // Nominatim returns a long comma-separated address. The first part is the
    // name people recognise; the rest is context.
    final parts = display.split(',').map((part) => part.trim()).toList();
    final name = '${json['name'] ?? ''}'.trim();
    final title = name.isNotEmpty ? name : parts.first;
    final rest = parts.where((part) => part != title).join(', ');

    return PlaceResult(
      title: title,
      subtitle: rest,
      latitude: lat,
      longitude: lon,
    );
  }
}
