import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/core/time/app_date_time.dart';

void main() {
  group('AppDateTime Unit Tests', () {
    test('normalizeUtc preserves UTC if already UTC', () {
      final utc = DateTime.utc(2026, 9, 21, 14, 0);
      final normalized = AppDateTime.normalizeUtc(utc);

      expect(normalized.isUtc, isTrue);
      expect(normalized, equals(utc));
    });

    test(
        'normalizeUtc converts local DateTime to UTC preserving the same moment',
        () {
      final local = DateTime(2026, 9, 21, 8, 30);
      final normalized = AppDateTime.normalizeUtc(local);

      expect(normalized.isUtc, isTrue);
      expect(normalized.isAtSameMomentAs(local), isTrue);
      expect(normalized, equals(local.toUtc()));
    });

    test('toStorage serializes to ISO-8601 UTC with "Z" suffix', () {
      final utc = DateTime.utc(2026, 9, 21, 16, 30, 45, 123);
      final stored = AppDateTime.toStorage(utc);

      expect(stored.endsWith('Z'), isTrue);
      expect(stored, equals('2026-09-21T16:30:45.123Z'));
    });

    test(
        'toStorage converts local DateTime to UTC before serializing with "Z" suffix',
        () {
      final local = DateTime(2026, 9, 21, 10, 0);
      final stored = AppDateTime.toStorage(local);

      expect(stored.endsWith('Z'), isTrue);
      expect(stored, equals(local.toUtc().toIso8601String()));
    });

    test(
        'fromStorage deserializes ISO-8601 UTC string to DateTime with isUtc == true',
        () {
      const stored = '2026-09-21T16:30:00.000Z';
      final parsed = AppDateTime.fromStorage(stored);

      expect(parsed.isUtc, isTrue);
      expect(parsed.year, equals(2026));
      expect(parsed.month, equals(9));
      expect(parsed.day, equals(21));
      expect(parsed.hour, equals(16));
      expect(parsed.minute, equals(30));
    });

    test(
        'fromStorage deserializes legacy ISO string without "Z" and returns UTC DateTime',
        () {
      const storedWithoutZ = '2026-09-21T10:30:00.000';
      final parsed = AppDateTime.fromStorage(storedWithoutZ);

      expect(parsed.isUtc, isTrue);
      expect(parsed, equals(DateTime.parse(storedWithoutZ).toUtc()));
    });

    test(
        'Round-trip DateTime -> toStorage -> fromStorage preserves instant and isUtc',
        () {
      final original = DateTime(2026, 9, 21, 11, 45, 30, 500);
      final stored = AppDateTime.toStorage(original);
      final rehydrated = AppDateTime.fromStorage(stored);

      expect(rehydrated.isUtc, isTrue);
      expect(rehydrated.isAtSameMomentAs(original), isTrue);
      expect(rehydrated, equals(original.toUtc()));
    });

    test('toLocal converts UTC DateTime to local representation', () {
      final utc = DateTime.utc(2026, 9, 21, 18, 0);
      final local = AppDateTime.toLocal(utc);

      expect(local.isUtc, isFalse);
      expect(local.isAtSameMomentAs(utc), isTrue);
    });
  });
}
