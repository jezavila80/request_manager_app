import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/features/requests/domain/request_fulfillment_status.dart';
import 'package:request_manager_app/features/requests/domain/request_list_item.dart';

void main() {
  group('RequestListItem Domain Model Tests', () {
    test('creates valid RequestListItem and derives correct status', () {
      final item = RequestListItem(
        requestId: 1,
        requesterId: 2,
        requesterName: 'María Soto',
        createdAt: DateTime.utc(2026, 9, 24, 10, 0),
        publicationCount: 4,
        quantityRequested: 8,
        quantityFulfilled: 3,
      );

      expect(item.requestId, equals(1));
      expect(item.requesterId, equals(2));
      expect(item.requesterName, equals('María Soto'));
      expect(item.createdAt.isUtc, isTrue);
      expect(item.publicationCount, equals(4));
      expect(item.quantityRequested, equals(8));
      expect(item.quantityFulfilled, equals(3));
      expect(item.fulfillmentStatus,
          equals(RequestFulfillmentStatus.partiallyFulfilled));
    });

    test('derives pending when quantityFulfilled is 0', () {
      final item = RequestListItem(
        requestId: 1,
        requesterId: 2,
        requesterName: 'Juan Pérez',
        createdAt: DateTime.utc(2026, 9, 23, 10, 0),
        publicationCount: 2,
        quantityRequested: 7,
        quantityFulfilled: 0,
      );

      expect(item.fulfillmentStatus, equals(RequestFulfillmentStatus.pending));
    });

    test('derives fulfilled when quantityFulfilled equals quantityRequested',
        () {
      final item = RequestListItem(
        requestId: 1,
        requesterId: 2,
        requesterName: 'Congregación La Calma',
        createdAt: DateTime.utc(2026, 9, 15, 10, 0),
        publicationCount: 3,
        quantityRequested: 12,
        quantityFulfilled: 12,
      );

      expect(
          item.fulfillmentStatus, equals(RequestFulfillmentStatus.fulfilled));
    });

    test('derives pending when publicationCount is 0', () {
      final item = RequestListItem(
        requestId: 1,
        requesterId: 2,
        requesterName: 'Sin publicaciones',
        createdAt: DateTime.utc(2026, 9, 15, 10, 0),
        publicationCount: 0,
        quantityRequested: 0,
        quantityFulfilled: 0,
      );

      expect(item.fulfillmentStatus, equals(RequestFulfillmentStatus.pending));
    });

    test('normalizes createdAt to UTC and trims requesterName', () {
      final localDate = DateTime(2026, 9, 24, 8, 30);
      final item = RequestListItem(
        requestId: 1,
        requesterId: 2,
        requesterName: '  María Soto  ',
        createdAt: localDate,
        publicationCount: 1,
        quantityRequested: 5,
        quantityFulfilled: 2,
      );

      expect(item.requesterName, equals('María Soto'));
      expect(item.createdAt.isUtc, isTrue);
      expect(item.createdAt, equals(localDate.toUtc()));
    });

    group('Invariants validation', () {
      test('throws ArgumentError when requestId <= 0', () {
        expect(
          () => RequestListItem(
            requestId: 0,
            requesterId: 1,
            requesterName: 'Test',
            createdAt: DateTime.utc(2026, 1, 1),
            publicationCount: 1,
            quantityRequested: 1,
            quantityFulfilled: 0,
          ),
          throwsArgumentError,
        );
      });

      test('throws ArgumentError when requesterId <= 0', () {
        expect(
          () => RequestListItem(
            requestId: 1,
            requesterId: 0,
            requesterName: 'Test',
            createdAt: DateTime.utc(2026, 1, 1),
            publicationCount: 1,
            quantityRequested: 1,
            quantityFulfilled: 0,
          ),
          throwsArgumentError,
        );
      });

      test(
          'throws ArgumentError when requesterName is empty or only whitespace',
          () {
        expect(
          () => RequestListItem(
            requestId: 1,
            requesterId: 1,
            requesterName: '   ',
            createdAt: DateTime.utc(2026, 1, 1),
            publicationCount: 1,
            quantityRequested: 1,
            quantityFulfilled: 0,
          ),
          throwsArgumentError,
        );
      });

      test('throws ArgumentError when publicationCount < 0', () {
        expect(
          () => RequestListItem(
            requestId: 1,
            requesterId: 1,
            requesterName: 'Test',
            createdAt: DateTime.utc(2026, 1, 1),
            publicationCount: -1,
            quantityRequested: 1,
            quantityFulfilled: 0,
          ),
          throwsArgumentError,
        );
      });

      test('throws ArgumentError when quantityRequested < 0', () {
        expect(
          () => RequestListItem(
            requestId: 1,
            requesterId: 1,
            requesterName: 'Test',
            createdAt: DateTime.utc(2026, 1, 1),
            publicationCount: 1,
            quantityRequested: -1,
            quantityFulfilled: 0,
          ),
          throwsArgumentError,
        );
      });

      test('throws ArgumentError when quantityFulfilled < 0', () {
        expect(
          () => RequestListItem(
            requestId: 1,
            requesterId: 1,
            requesterName: 'Test',
            createdAt: DateTime.utc(2026, 1, 1),
            publicationCount: 1,
            quantityRequested: 5,
            quantityFulfilled: -1,
          ),
          throwsArgumentError,
        );
      });

      test('throws ArgumentError when quantityFulfilled > quantityRequested',
          () {
        expect(
          () => RequestListItem(
            requestId: 1,
            requesterId: 1,
            requesterName: 'Test',
            createdAt: DateTime.utc(2026, 1, 1),
            publicationCount: 1,
            quantityRequested: 5,
            quantityFulfilled: 6,
          ),
          throwsArgumentError,
        );
      });
    });

    test('value equality and hashCode', () {
      final date = DateTime.utc(2026, 9, 24, 10, 0);
      final item1 = RequestListItem(
        requestId: 1,
        requesterId: 2,
        requesterName: 'María Soto',
        createdAt: date,
        publicationCount: 4,
        quantityRequested: 8,
        quantityFulfilled: 3,
      );

      final item2 = RequestListItem(
        requestId: 1,
        requesterId: 2,
        requesterName: 'María Soto',
        createdAt: date,
        publicationCount: 4,
        quantityRequested: 8,
        quantityFulfilled: 3,
      );

      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));
      expect(item1.toString(), contains('María Soto'));
    });
  });
}
