import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/core/database/database_constants.dart';
import 'package:request_manager_app/features/requests/data/mappers/request_item_mapper.dart';
import 'package:request_manager_app/features/requests/data/mappers/request_list_item_mapper.dart';
import 'package:request_manager_app/features/requests/data/mappers/request_mapper.dart';
import 'package:request_manager_app/features/requests/domain/request.dart';
import 'package:request_manager_app/features/requests/domain/request_fulfillment_status.dart';
import 'package:request_manager_app/features/requests/domain/request_item.dart';

void main() {
  group('Request and RequestItem Mapper Unit Tests', () {
    final tCreatedAt = DateTime.utc(2026, 9, 7, 10, 0);
    final tUpdatedAt = DateTime.utc(2026, 9, 7, 12, 0);

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

    test(
        'RequestMapper.toMap converts Request header to database map with UTC "Z" suffix',
        () {
      final request = Request(
        id: 15,
        requesterId: 10,
        notes: 'Notas de entrega',
        createdAt: tCreatedAt,
        updatedAt: tUpdatedAt,
      );

      final map = RequestMapper.toMap(request);

      expect(map[DatabaseConstants.columnId], equals(15));
      expect(map[DatabaseConstants.columnRequesterId], equals(10));
      expect(map[DatabaseConstants.columnNotes], equals('Notas de entrega'));
      expect((map[DatabaseConstants.columnCreatedAt] as String).endsWith('Z'),
          isTrue);
      expect((map[DatabaseConstants.columnUpdatedAt] as String).endsWith('Z'),
          isTrue);
      expect(map[DatabaseConstants.columnCreatedAt],
          equals('2026-09-07T10:00:00.000Z'));
      expect(map[DatabaseConstants.columnUpdatedAt],
          equals('2026-09-07T12:00:00.000Z'));
    });

    test(
        'RequestMapper.toMap converts local DateTime input to UTC ISO-8601 with "Z" suffix',
        () {
      final localCreated = DateTime(2026, 9, 7, 8, 0);
      final localUpdated = DateTime(2026, 9, 7, 9, 0);

      final request = Request(
        id: 16,
        requesterId: 12,
        createdAt: localCreated,
        updatedAt: localUpdated,
      );

      final map = RequestMapper.toMap(request);
      final storedCreated = map[DatabaseConstants.columnCreatedAt] as String;
      final storedUpdated = map[DatabaseConstants.columnUpdatedAt] as String;

      expect(storedCreated.endsWith('Z'), isTrue);
      expect(storedUpdated.endsWith('Z'), isTrue);
      expect(storedCreated, equals(localCreated.toUtc().toIso8601String()));
      expect(storedUpdated, equals(localUpdated.toUtc().toIso8601String()));
    });

    test(
        'RequestMapper.fromMap reconstructs Request with associated items and UTC timestamps',
        () {
      final item = RequestItem(
        id: 101,
        publicationId: 8,
        quantityRequested: 5,
      );

      final map = {
        DatabaseConstants.columnId: 15,
        DatabaseConstants.columnRequesterId: 10,
        DatabaseConstants.columnNotes: 'Notas de entrega',
        DatabaseConstants.columnCreatedAt: '2026-09-07T10:00:00.000Z',
        DatabaseConstants.columnUpdatedAt: '2026-09-07T12:00:00.000Z',
      };

      final request = RequestMapper.fromMap(map, items: [item]);

      expect(request.id, equals(15));
      expect(request.requesterId, equals(10));
      expect(request.notes, equals('Notas de entrega'));
      expect(request.items.length, equals(1));
      expect(request.items.first, equals(item));
      expect(request.createdAt.isUtc, isTrue);
      expect(request.updatedAt.isUtc, isTrue);
      expect(request.createdAt, equals(tCreatedAt));
      expect(request.updatedAt, equals(tUpdatedAt));
    });

    test(
        'RequestMapper.fromMap accepts legacy string without "Z" and produces UTC DateTime',
        () {
      final map = {
        DatabaseConstants.columnId: 20,
        DatabaseConstants.columnRequesterId: 5,
        DatabaseConstants.columnCreatedAt: '2026-09-07T10:00:00.000',
        DatabaseConstants.columnUpdatedAt: '2026-09-07T12:00:00.000',
      };

      final request = RequestMapper.fromMap(map);

      expect(request.requesterId, equals(5));
      expect(request.createdAt.isUtc, isTrue);
      expect(request.updatedAt.isUtc, isTrue);
    });

    test(
        'RequestMapper.fromMap throws FormatException when created_at or updated_at is null or empty',
        () {
      final validMap = {
        DatabaseConstants.columnId: 1,
        DatabaseConstants.columnRequesterId: 1,
        DatabaseConstants.columnCreatedAt: '2026-09-07T10:00:00.000Z',
        DatabaseConstants.columnUpdatedAt: '2026-09-07T12:00:00.000Z',
      };

      final mapNoCreatedAt = Map<String, Object?>.from(validMap)
        ..remove(DatabaseConstants.columnCreatedAt);
      expect(
        () => RequestMapper.fromMap(mapNoCreatedAt),
        throwsA(isA<FormatException>()),
      );

      final mapNoUpdatedAt = Map<String, Object?>.from(validMap)
        ..remove(DatabaseConstants.columnUpdatedAt);
      expect(
        () => RequestMapper.fromMap(mapNoUpdatedAt),
        throwsA(isA<FormatException>()),
      );

      final mapEmptyCreatedAt = Map<String, Object?>.from(validMap)
        ..[DatabaseConstants.columnCreatedAt] = '   ';
      expect(
        () => RequestMapper.fromMap(mapEmptyCreatedAt),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('RequestListItemMapper Unit Tests', () {
    test('reconstructs valid RequestListItem from query map', () {
      final map = {
        RequestListItemMapper.columnRequestId: 10,
        RequestListItemMapper.columnRequesterId: 3,
        RequestListItemMapper.columnRequesterName: 'María Soto',
        RequestListItemMapper.columnCreatedAt: '2026-09-24T10:00:00.000Z',
        RequestListItemMapper.columnPublicationCount: 4,
        RequestListItemMapper.columnQuantityRequested: 8,
        RequestListItemMapper.columnQuantityFulfilled: 3,
      };

      final item = RequestListItemMapper.fromMap(map);

      expect(item.requestId, equals(10));
      expect(item.requesterId, equals(3));
      expect(item.requesterName, equals('María Soto'));
      expect(item.createdAt, equals(DateTime.utc(2026, 9, 24, 10, 0)));
      expect(item.publicationCount, equals(4));
      expect(item.quantityRequested, equals(8));
      expect(item.quantityFulfilled, equals(3));
      expect(item.fulfillmentStatus,
          equals(RequestFulfillmentStatus.partiallyFulfilled));
    });

    test('defaults null counts and quantities to 0', () {
      final map = {
        RequestListItemMapper.columnRequestId: 12,
        RequestListItemMapper.columnRequesterId: 5,
        RequestListItemMapper.columnRequesterName: 'Juan Pérez',
        RequestListItemMapper.columnCreatedAt: '2026-09-24T10:00:00.000Z',
        RequestListItemMapper.columnPublicationCount: null,
        RequestListItemMapper.columnQuantityRequested: null,
        RequestListItemMapper.columnQuantityFulfilled: null,
      };

      final item = RequestListItemMapper.fromMap(map);

      expect(item.publicationCount, equals(0));
      expect(item.quantityRequested, equals(0));
      expect(item.quantityFulfilled, equals(0));
      expect(item.fulfillmentStatus, equals(RequestFulfillmentStatus.pending));
    });

    test('throws FormatException when required columns are missing', () {
      final validMap = {
        RequestListItemMapper.columnRequestId: 10,
        RequestListItemMapper.columnRequesterId: 3,
        RequestListItemMapper.columnRequesterName: 'María Soto',
        RequestListItemMapper.columnCreatedAt: '2026-09-24T10:00:00.000Z',
        RequestListItemMapper.columnPublicationCount: 1,
        RequestListItemMapper.columnQuantityRequested: 2,
        RequestListItemMapper.columnQuantityFulfilled: 1,
      };

      final noRequestId = Map<String, Object?>.from(validMap)
        ..remove(RequestListItemMapper.columnRequestId);
      expect(() => RequestListItemMapper.fromMap(noRequestId),
          throwsFormatException);

      final noRequesterId = Map<String, Object?>.from(validMap)
        ..remove(RequestListItemMapper.columnRequesterId);
      expect(() => RequestListItemMapper.fromMap(noRequesterId),
          throwsFormatException);

      final noRequesterName = Map<String, Object?>.from(validMap)
        ..remove(RequestListItemMapper.columnRequesterName);
      expect(() => RequestListItemMapper.fromMap(noRequesterName),
          throwsFormatException);

      final emptyRequesterName = Map<String, Object?>.from(validMap)
        ..[RequestListItemMapper.columnRequesterName] = '   ';
      expect(() => RequestListItemMapper.fromMap(emptyRequesterName),
          throwsFormatException);

      final noCreatedAt = Map<String, Object?>.from(validMap)
        ..remove(RequestListItemMapper.columnCreatedAt);
      expect(() => RequestListItemMapper.fromMap(noCreatedAt),
          throwsFormatException);
    });
  });
}
