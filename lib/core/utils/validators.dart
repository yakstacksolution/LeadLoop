/// Pure form-validation helpers.
///
/// Each returns `null` when the value is acceptable and an error string
/// otherwise, matching Flutter's `FormFieldValidator` contract.
abstract final class Validators {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Nepali numbers are 10 digits; we also accept a +977 prefix and the
  /// separators people actually type.
  static final _phonePattern = RegExp(r'^(\+977[-\s]?)?[0-9][0-9\-\s]{6,14}$');

  static String? required(String? value, [String field = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$field is required.';
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required.';
    if (!_emailPattern.hasMatch(text)) return 'Enter a valid email address.';
    return null;
  }

  static String? optionalEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return _emailPattern.hasMatch(text) ? null : 'Enter a valid email address.';
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required.';
    if (text.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  static String? phone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Phone number is required.';
    if (!_phonePattern.hasMatch(text)) return 'Enter a valid phone number.';
    return null;
  }

  static String? optionalPhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return _phonePattern.hasMatch(text) ? null : 'Enter a valid phone number.';
  }

  static String? minLength(String? value, int min, [String field = 'This field']) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$field is required.';
    if (text.length < min) return '$field must be at least $min characters.';
    return null;
  }

  /// Court counts are optional, but when supplied must be a sane positive int.
  static String? courtCount(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = int.tryParse(text);
    if (parsed == null) return 'Enter a whole number.';
    if (parsed < 0) return 'Cannot be negative.';
    if (parsed > 100) return 'That seems too high.';
    return null;
  }

  /// Latitude/longitude typed by hand, e.g. pasted from Google Maps.
  static String? latitude(String? value) => _coordinate(value, 90, 'Latitude');
  static String? longitude(String? value) => _coordinate(value, 180, 'Longitude');

  static String? _coordinate(String? value, num bound, String field) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null) return 'Enter a valid $field.';
    if (parsed < -bound || parsed > bound) return '$field must be between -$bound and $bound.';
    return null;
  }
}
