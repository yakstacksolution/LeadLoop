import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_lead/features/employees/data/datasources/account_provisioner.dart';

void main() {
  group('generatePassword', () {
    test('meets Firebase\'s minimum length with room to spare', () {
      expect(AccountProvisioner.generatePassword().length, 14);
      expect(AccountProvisioner.generatePassword(length: 20).length, 20);
    });

    test('is not predictable', () {
      final generated = List.generate(50, (_) => AccountProvisioner.generatePassword());
      expect(generated.toSet().length, 50);
    });

    test('avoids characters that are easy to misread when read aloud', () {
      // No l, I, 1, O, 0 — an admin hands these over verbally or by hand.
      final sample = List.generate(200, (_) => AccountProvisioner.generatePassword()).join();
      for (final ambiguous in ['l', 'I', '1', 'O', '0']) {
        expect(sample.contains(ambiguous), isFalse, reason: 'contains "$ambiguous"');
      }
    });

    test('always clears the 8-character rule the validator enforces', () {
      for (var i = 0; i < 100; i++) {
        expect(AccountProvisioner.generatePassword().length, greaterThanOrEqualTo(8));
      }
    });
  });
}
