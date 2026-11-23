import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_lead/core/utils/validators.dart';

void main() {
  group('email', () {
    test('accepts a normal address', () {
      expect(Validators.email('dilli@hamrofutsal.com'), isNull);
    });

    test('rejects a missing domain', () {
      expect(Validators.email('dilli@'), isNotNull);
    });

    test('rejects an empty value', () {
      expect(Validators.email(''), 'Email is required.');
    });

    test('optionalEmail allows empty but still validates a value', () {
      expect(Validators.optionalEmail(''), isNull);
      expect(Validators.optionalEmail('nope'), isNotNull);
    });
  });

  group('phone', () {
    test('accepts a 10-digit Nepali mobile number', () {
      expect(Validators.phone('9841234567'), isNull);
    });

    test('accepts a +977 country prefix', () {
      expect(Validators.phone('+977 9841234567'), isNull);
    });

    test('rejects something far too short', () {
      expect(Validators.phone('12'), isNotNull);
    });

    test('optionalPhone allows empty', () {
      expect(Validators.optionalPhone(''), isNull);
    });
  });

  group('password', () {
    test('requires at least eight characters', () {
      expect(Validators.password('short'), 'Use at least 8 characters.');
      expect(Validators.password('longenough'), isNull);
    });
  });

  group('courtCount', () {
    test('is optional', () {
      expect(Validators.courtCount(''), isNull);
    });

    test('rejects non-numbers and negatives', () {
      expect(Validators.courtCount('two'), isNotNull);
      expect(Validators.courtCount('-1'), isNotNull);
    });

    test('accepts a plausible count', () {
      expect(Validators.courtCount('3'), isNull);
    });
  });

  group('coordinates', () {
    test('latitude must be within ±90', () {
      expect(Validators.latitude('27.7172'), isNull);
      expect(Validators.latitude('120'), isNotNull);
    });

    test('longitude must be within ±180', () {
      expect(Validators.longitude('85.3240'), isNull);
      expect(Validators.longitude('200'), isNotNull);
    });

    test('blank coordinates are allowed', () {
      expect(Validators.latitude(''), isNull);
      expect(Validators.longitude(''), isNull);
    });
  });
}
