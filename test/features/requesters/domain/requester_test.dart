import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/features/requesters/domain/requester.dart';
import 'package:request_manager_app/features/requesters/domain/services/requester_name_cleaner.dart';

void main() {
  group('Requester Domain Entity & Name Validation Tests', () {
    final t0 = DateTime.utc(2026, 9, 22, 10, 0);
    final t1 = DateTime.utc(2026, 9, 22, 11, 0);

    test('Valid names with at least two significant words succeed', () {
      final validNames = [
        'Maria Soto',
        'José Pérez',
        'Juan Carlos',
        'Congregación La Calma',
        'Salón Central',
        'María de los Ángeles',
        'Ana Belén',
      ];

      for (final name in validNames) {
        final requester = Requester(
          id: 1,
          name: name,
          createdAt: t0,
          updatedAt: t0,
        );

        expect(requester.name, equals(RequesterNameCleaner.clean(name)));
        expect(requester.isActive, isTrue);
        expect(requester.createdAt, equals(t0));
        expect(requester.updatedAt, equals(t0));
      }
    });

    test('Invalid names with fewer than two significant words are rejected',
        () {
      final invalidNames = [
        'Maria',
        'Pepe',
        'Congregación',
        '123',
        '   ',
        '123 456',
        '',
        'A',
      ];

      for (final name in invalidNames) {
        expect(
          () => Requester(
            name: name,
            createdAt: t0,
            updatedAt: t0,
          ),
          throwsA(isA<ArgumentError>()),
          reason: 'Expected "$name" to be rejected',
        );
      }
    });

    test('Display name cleaning preserves accents but collapses whitespace',
        () {
      final requester = Requester(
        name: '   María    Soto   ',
        createdAt: t0,
        updatedAt: t0,
      );

      expect(requester.name, equals('María Soto'));
      expect(requester.normalizedName, equals('maria soto'));
    });

    test('Rejects non-positive ID', () {
      expect(
        () => Requester(
          id: 0,
          name: 'Carlos Ruiz',
          createdAt: t0,
          updatedAt: t0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => Requester(
          id: -5,
          name: 'Carlos Ruiz',
          createdAt: t0,
          updatedAt: t0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Rejects updatedAt earlier than createdAt', () {
      expect(
        () => Requester(
          name: 'Carlos Ruiz',
          createdAt: t1,
          updatedAt: t0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('copyWith updates fields and preserves unchanged', () {
      final original = Requester(
        id: 1,
        name: 'María Soto',
        createdAt: t0,
        updatedAt: t0,
      );

      final updated = original.copyWith(
        name: 'María Gómez',
        updatedAt: t1,
      );

      expect(updated.id, equals(1));
      expect(updated.name, equals('María Gómez'));
      expect(updated.normalizedName, equals('maria gomez'));
      expect(updated.createdAt, equals(t0));
      expect(updated.updatedAt, equals(t1));
    });

    test('Value equality and hashCode work as expected', () {
      final r1 = Requester(
        id: 1,
        name: 'María Soto',
        createdAt: t0,
        updatedAt: t0,
      );

      final r2 = Requester(
        id: 1,
        name: '  María   Soto  ',
        createdAt: t0,
        updatedAt: t0,
      );

      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
    });
  });
}
