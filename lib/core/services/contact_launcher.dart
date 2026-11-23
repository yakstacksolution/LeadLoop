import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the phone dialler, SMS composer, WhatsApp/Viber or mail client for a
/// venue contact.
///
/// Every method returns false rather than throwing when no app can handle the
/// scheme — an old field phone without WhatsApp installed is a normal case,
/// and the caller shows a snackbar instead of an error screen.
abstract final class ContactLauncher {
  /// Strips spaces, dashes and brackets, keeping a leading `+`.
  static String normalisePhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.startsWith('+')) return '+${cleaned.replaceAll('+', '')}';
    return cleaned.replaceAll('+', '');
  }

  static Future<bool> call(String phone) =>
      _open(Uri(scheme: 'tel', path: normalisePhone(phone)));

  static Future<bool> sms(String phone) =>
      _open(Uri(scheme: 'sms', path: normalisePhone(phone)));

  static Future<bool> email(String address, {String? subject}) => _open(
        Uri(
          scheme: 'mailto',
          path: address.trim(),
          queryParameters: subject == null ? null : {'subject': subject},
        ),
      );

  /// wa.me needs a country code, so a local number without one is rejected
  /// up front rather than opening WhatsApp on a broken chat.
  static Future<bool> whatsapp(String phone) {
    final number = normalisePhone(phone).replaceAll('+', '');
    if (number.length < 10) return Future.value(false);
    return _open(Uri.parse('https://wa.me/$number'));
  }

  static Future<bool> viber(String phone) =>
      _open(Uri.parse('viber://chat?number=${normalisePhone(phone)}'));

  /// Opens the point in whatever map app the device has. Falls back to the
  /// Google Maps web URL, which every platform can open.
  static Future<bool> directions(double latitude, double longitude, {String? label}) async {
    final query = '$latitude,$longitude';
    final geo = Uri.parse(
      'geo:$query?q=$query${label == null ? '' : '(${Uri.encodeComponent(label)})'}',
    );
    if (await _open(geo)) return true;
    return _open(
      Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query}),
    );
  }

  static Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  static Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
