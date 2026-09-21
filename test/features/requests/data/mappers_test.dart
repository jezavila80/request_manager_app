import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/core/database/database_constants.dart';
import 'package:request_manager_app/features/requests/data/mappers/request_item_mapper.dart';
import 'package:request_manager_app/features/requests/data/mappers/request_mapper.dart';
import 'package:request_manager_app/features/requests/domain/request.dart';
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
        requestedBy: 'Juan Pérez',
        notes: 'Notas de entrega',
        createdAt: tCreatedAt,
        updatedAt: tUpdatedAt,
      );

      final map = RequestMapper.toMap(request);

      expect(map[DatabaseConstants.columnId], equals(15));
      expect(map[DatabaseConstants.columnRequestedBy], equals('Juan Pérez'));
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
        requestedBy: 'María Gómez',
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
        DatabaseConstants.columnRequestedBy: 'Juan Pérez',
        DatabaseConstants.columnNotes: 'Notas de entrega',
        DatabaseConstants.columnCreatedAt: '2026-09-07T10:00:00.000Z',
        DatabaseConstants.columnUpdatedAt: '2026-09-07T12:00:00.000Z',
      };

      final request = RequestMapper.fromMap(map, items: [item]);

      expect(request.id, equals(15));
      expect(request.requestedBy, equals('Juan Pérez'));
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
        DatabaseConstants.columnRequestedBy: 'Ana',
        DatabaseConstants.columnCreatedAt: '2026-09-07T10:00:00.000',
        DatabaseConstants.columnUpdatedAt: '2026-09-07T12:00:00.000',
      };

      final request = RequestMapper.fromMap(map);

      expect(request.createdAt.isUtc, isTrue);
      expect(request.updatedAt.isUtc, isTrue);
    });

    test(
        'RequestMapper.fromMap throws FormatException when created_at or updated_at is null or empty',
        () {
      final validMap = {
        DatabaseConstants.columnId: 1,
        DatabaseConstants.columnRequestedBy: 'Usuario',
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
}
