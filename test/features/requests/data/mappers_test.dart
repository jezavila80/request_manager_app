import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/core/database/database_constants.dart';
import 'package:request_manager_app/features/requests/data/mappers/request_item_mapper.dart';
import 'package:request_manager_app/features/requests/data/mappers/request_mapper.dart';
import 'package:request_manager_app/features/requests/domain/request.dart';
import 'package:request_manager_app/features/requests/domain/request_item.dart';

void main() {
  group('Request and RequestItem Mapper Unit Tests', () {
    final tCreatedAt = DateTime(2026, 9, 7, 10, 0);
    final tUpdatedAt = DateTime(2026, 9, 7, 12, 0);

    test('RequestItemMapper.toMap includes all database columns', () {
      final item = RequestItem(
        id: 101,
        publicationId: 8,
        quantityRequested: 10,
        quantityFulfilled: 3,
      );

      final map = RequestItemMapper.toMap(item, requestId: 15);

      expect(map[DatabaseConstants.columnId], equals(101));
      expect(map[DatabaseConstants.columnRequestId], equals(15));
      expect(map[DatabaseConstants.columnPublicationId], equals(8));
      expect(map[DatabaseConstants.columnQuantityRequested], equals(10));
      expect(map[DatabaseConstants.columnQuantityFulfilled], equals(3));
    });

    test('RequestItemMapper.fromMap reconstructs valid RequestItem', () {
      final map = {
        DatabaseConstants.columnId: 101,
        DatabaseConstants.columnRequestId: 15,
        DatabaseConstants.columnPublicationId: 8,
        DatabaseConstants.columnQuantityRequested: 10,
        DatabaseConstants.columnQuantityFulfilled: 3,
      };

      final item = RequestItemMapper.fromMap(map);

      expect(item.id, equals(101));
      expect(item.publicationId, equals(8));
      expect(item.quantityRequested, equals(10));
      expect(item.quantityFulfilled, equals(3));
    });

    test('RequestMapper.toMap converts Request header to database map', () {
      final request = Request(
        id: 15,
        requestedBy: 'Juan Pérez',
        notes: 'Notas de entrega',
        createdAt: tCreatedAt,
        updatedAt: tUpdatedAt,
      );

      final map = RequestMapper.toMap(request);

      expect(map[DatabaseConstants.columnId], equals(15));
      expect(map[DatabaseConstants.columnRequestedBy], equals('Juan Pérez'));
      expect(map[DatabaseConstants.columnNotes], equals('Notas de entrega'));
      expect(
          map[DatabaseConstants.columnCreatedAt], tCreatedAt.toIso8601String());
      expect(
          map[DatabaseConstants.columnUpdatedAt], tUpdatedAt.toIso8601String());
    });

    test('RequestMapper.fromMap reconstructs Request with associated items',
        () {
      final item = RequestItem(
        id: 101,
        publicationId: 8,
        quantityRequested: 5,
      );

      final map = {
        DatabaseConstants.columnId: 15,
        DatabaseConstants.columnRequestedBy: 'Juan Pérez',
        DatabaseConstants.columnNotes: 'Notas de entrega',
        DatabaseConstants.columnCreatedAt: tCreatedAt.toIso8601String(),
        DatabaseConstants.columnUpdatedAt: tUpdatedAt.toIso8601String(),
      };

      final request = RequestMapper.fromMap(map, items: [item]);

      expect(request.id, equals(15));
      expect(request.requestedBy, equals('Juan Pérez'));
      expect(request.notes, equals('Notas de entrega'));
      expect(request.items.length, equals(1));
      expect(request.items.first, equals(item));
      expect(request.createdAt, equals(tCreatedAt));
      expect(request.updatedAt, equals(tUpdatedAt));
    });
  });
}
