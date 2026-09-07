import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/features/requests/domain/request_item.dart';

void main() {
  group('RequestItem Domain Entity Tests', () {
    test('Creates valid RequestItem with default quantityFulfilled = 0', () {
      final item = RequestItem(
        id: 1,
        publicationId: 10,
        quantityRequested: 5,
      );

      expect(item.id, equals(1));
      expect(item.publicationId, equals(10));
      expect(item.quantityRequested, equals(5));
      expect(item.quantityFulfilled, equals(0));
    });

    test('Creates valid RequestItem with partial or full quantityFulfilled',
        () {
      final partialItem = RequestItem(
        publicationId: 10,
        quantityRequested: 5,
        quantityFulfilled: 3,
      );
      expect(partialItem.quantityFulfilled, equals(3));

      final fullItem = RequestItem(
        publicationId: 10,
        quantityRequested: 5,
        quantityFulfilled: 5,
      );
      expect(fullItem.quantityFulfilled, equals(5));
    });

    test('Throws ArgumentError if id <= 0', () {
      expect(
        () => RequestItem(
          id: 0,
          publicationId: 10,
          quantityRequested: 5,
        ),
        throwsArgumentError,
      );
      expect(
        () => RequestItem(
          id: -1,
          publicationId: 10,
          quantityRequested: 5,
        ),
        throwsArgumentError,
      );
    });

    test('Throws ArgumentError if publicationId <= 0', () {
      expect(
        () => RequestItem(
          publicationId: 0,
          quantityRequested: 5,
        ),
        throwsArgumentError,
      );
      expect(
        () => RequestItem(
          publicationId: -5,
          quantityRequested: 5,
        ),
        throwsArgumentError,
      );
    });

    test('Throws ArgumentError if quantityRequested <= 0', () {
      expect(
        () => RequestItem(
          publicationId: 10,
          quantityRequested: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => RequestItem(
          publicationId: 10,
          quantityRequested: -3,
        ),
        throwsArgumentError,
      );
    });

    test('Throws ArgumentError if quantityFulfilled < 0', () {
      expect(
        () => RequestItem(
          publicationId: 10,
          quantityRequested: 5,
          quantityFulfilled: -1,
        ),
        throwsArgumentError,
      );
    });

    test(
        'Throws ArgumentError if quantityFulfilled is greater than quantityRequested',
        () {
      expect(
        () => RequestItem(
          publicationId: 10,
          quantityRequested: 5,
          quantityFulfilled: 6,
        ),
        throwsArgumentError,
      );
    });

    test(
        'replacePublication updates publicationId preserving id and quantities',
        () {
      final original = RequestItem(
        id: 42,
        publicationId: 35,
        quantityRequested: 10,
        quantityFulfilled: 4,
      );

      final replaced = original.replacePublication(8);

      expect(replaced.id, equals(42));
      expect(replaced.publicationId, equals(8));
      expect(replaced.quantityRequested, equals(10));
      expect(replaced.quantityFulfilled, equals(4));
    });

    test(
        'withQuantityRequested updates quantityRequested validating invariants',
        () {
      final item = RequestItem(
        publicationId: 10,
        quantityRequested: 5,
        quantityFulfilled: 2,
      );

      final updated = item.withQuantityRequested(8);
      expect(updated.quantityRequested, equals(8));
      expect(updated.quantityFulfilled, equals(2));

      expect(
        () => item.withQuantityRequested(1),
        throwsArgumentError,
      );
    });

    test(
        'withQuantityFulfilled updates quantityFulfilled validating invariants',
        () {
      final item = RequestItem(
        publicationId: 10,
        quantityRequested: 5,
        quantityFulfilled: 2,
      );

      final updated = item.withQuantityFulfilled(5);
      expect(updated.quantityFulfilled, equals(5));

      expect(
        () => item.withQuantityFulfilled(6),
        throwsArgumentError,
      );
    });

    test('copyWith updates specified fields and preserves remaining ones', () {
      final item = RequestItem(
        id: 1,
        publicationId: 10,
        quantityRequested: 5,
        quantityFulfilled: 2,
      );

      final copied = item.copyWith(quantityFulfilled: 4);

      expect(copied.id, equals(1));
      expect(copied.publicationId, equals(10));
      expect(copied.quantityRequested, equals(5));
      expect(copied.quantityFulfilled, equals(4));
    });

    test('Supports value equality (==) and hashCode', () {
      final item1 = RequestItem(
        id: 1,
        publicationId: 10,
        quantityRequested: 5,
        quantityFulfilled: 2,
      );
      final item2 = RequestItem(
        id: 1,
        publicationId: 10,
        quantityRequested: 5,
        quantityFulfilled: 2,
      );
      final item3 = RequestItem(
        id: 1,
        publicationId: 10,
        quantityRequested: 5,
        quantityFulfilled: 3,
      );

      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));
      expect(item1, isNot(equals(item3)));
    });

    test('toString returns informative text representation', () {
      final item = RequestItem(
        id: 7,
        publicationId: 10,
        quantityRequested: 5,
        quantityFulfilled: 2,
      );

      expect(
        item.toString(),
        equals(
            'RequestItem(id: 7, publicationId: 10, requested: 5, fulfilled: 2)'),
      );
    });
  });
}
