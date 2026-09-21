import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/core/time/app_clock.dart';

import 'fixed_clock.dart';

void main() {
  group('AppClock & Clock Implementations Unit Tests', () {
    test(
        'SystemClock.nowUtc returns a DateTime with isUtc == true within a valid window',
        () {
      const clock = SystemClock();
      final before =
          DateTime.now().toUtc().subtract(const Duration(seconds: 1));
      final now = clock.nowUtc();
      final after = DateTime.now().toUtc().add(const Duration(seconds: 1));

      expect(now.isUtc, isTrue);
      expect(now.isAfter(before), isTrue);
      expect(now.isBefore(after), isTrue);
    });

    test(
        'FixedClock returns deterministic UTC timestamp regardless of input timezone',
        () {
      final localInstant = DateTime(2026, 9, 21, 10, 30);
      final clock = FixedClock(localInstant);

      final result1 = clock.nowUtc();
      final result2 = clock.nowUtc();

      expect(result1.isUtc, isTrue);
      expect(result2.isUtc, isTrue);
      expect(result1, equals(result2));
      expect(result1.isAtSameMomentAs(localInstant), isTrue);
      expect(result1, equals(localInstant.toUtc()));
    });
  });
}
