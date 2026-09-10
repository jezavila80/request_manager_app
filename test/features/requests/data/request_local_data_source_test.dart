import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/core/database/app_database.dart';
import 'package:request_manager_app/core/database/database_constants.dart';
import 'package:request_manager_app/features/requests/data/datasources/request_local_data_source.dart';
import 'package:request_manager_app/features/requests/domain/request.dart';
import 'package:request_manager_app/features/requests/domain/request_exceptions.dart';
import 'package:request_manager_app/features/requests/domain/request_item.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('RequestLocalDataSourceImpl Unit & SQLite Integration Tests', () {
    late Database db;
    late RequestLocalDataSourceImpl dataSource;

    setUp(() async {
      db = await AppDatabase.instance.initDatabaseForTesting(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      dataSource =
          RequestLocalDataSourceImpl(appDatabase: AppDatabase.instance);
    });

    tearDown(() async {
      await AppDatabase.instance.close();
    });

    Future<int> insertSamplePublication({
      String? code = 'PUB-1',
      String name = 'Publicación de prueba',
    }) async {
      final nowStr = DateTime.now().toIso8601String();
      return await db.insert(DatabaseConstants.tablePublications, {
        DatabaseConstants.columnCode: code,
        DatabaseConstants.columnName: name,
        DatabaseConstants.columnCreatedAt: nowStr,
        DatabaseConstants.columnUpdatedAt: nowStr,
      });
    }

    test('create successfully persists Request with 1 item and returns IDs',
        () async {
      final pubId = await insertSamplePublication();
      final now = DateTime.now();

      final originalRequest = Request(
        requestedBy: 'Juan Pérez',
        notes: 'Urgente',
        items: [
          RequestItem(
            publicationId: pubId,
            quantityRequested: 5,
            quantityFulfilled: 0,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final persistedRequest = await dataSource.create(originalRequest);

      // Verify returned aggregate has IDs
      expect(persistedRequest.id, isNotNull);
      expect(persistedRequest.id, greaterThan(0));
      expect(persistedRequest.items.length, equals(1));
      expect(persistedRequest.items.first.id, isNotNull);
      expect(persistedRequest.items.first.id, greaterThan(0));

      // Direct SQLite query verification
      final reqRows = await db.query(
        DatabaseConstants.tableRequests,
        where: 'id = ?',
        whereArgs: [persistedRequest.id],
      );
      expect(reqRows.length, equals(1));
      expect(reqRows.first[DatabaseConstants.columnRequestedBy],
          equals('Juan Pérez'));
      expect(reqRows.first[DatabaseConstants.columnNotes], equals('Urgente'));

      final itemRows = await db.query(
        DatabaseConstants.tableRequestItems,
        where: 'request_id = ?',
        whereArgs: [persistedRequest.id],
      );
      expect(itemRows.length, equals(1));
      expect(
          itemRows.first[DatabaseConstants.columnPublicationId], equals(pubId));
      expect(
          itemRows.first[DatabaseConstants.columnQuantityRequested], equals(5));
    });

    test(
        'create successfully persists Request with multiple items in exact order',
        () async {
      final pub1 = await insertSamplePublication(code: 'PUB-1', name: 'Pub A');
      final pub2 = await insertSamplePublication(code: 'PUB-2', name: 'Pub B');
      final pub3 = await insertSamplePublication(code: 'PUB-3', name: 'Pub C');

      final originalRequest = Request(
        requestedBy: 'María',
        items: [
          RequestItem(publicationId: pub1, quantityRequested: 2),
          RequestItem(publicationId: pub2, quantityRequested: 4),
          RequestItem(publicationId: pub3, quantityRequested: 1),
        ],
      );

      final persistedRequest = await dataSource.create(originalRequest);

      expect(persistedRequest.id, greaterThan(0));
      expect(persistedRequest.items.length, equals(3));

      // Verify preserved logical order
      expect(persistedRequest.items[0].publicationId, equals(pub1));
      expect(persistedRequest.items[1].publicationId, equals(pub2));
      expect(persistedRequest.items[2].publicationId, equals(pub3));

      for (final item in persistedRequest.items) {
        expect(item.id, isNotNull);
        expect(item.id, greaterThan(0));
      }

      final itemRows = await db.query(
        DatabaseConstants.tableRequestItems,
        where: 'request_id = ?',
        whereArgs: [persistedRequest.id],
        orderBy: 'id ASC',
      );
      expect(itemRows.length, equals(3));
    });

    test('create preserves original Request instance immutability', () async {
      final pubId = await insertSamplePublication();
      final originalItem =
          RequestItem(publicationId: pubId, quantityRequested: 3);
      final originalRequest = Request(
        requestedBy: 'Carlos',
        items: [originalItem],
      );

      final persistedRequest = await dataSource.create(originalRequest);

      // Original request and items must remain null
      expect(originalRequest.id, isNull);
      expect(originalRequest.items.first.id, isNull);

      // Persisted request must have valid IDs
      expect(persistedRequest.id, isNotNull);
      expect(persistedRequest.items.first.id, isNotNull);
    });

    test('create rejects Request with pre-existing id (id != null)', () async {
      final pubId = await insertSamplePublication();
      final invalidRequest = Request(
        id: 99,
        requestedBy: 'Carlos',
        items: [RequestItem(publicationId: pubId, quantityRequested: 1)],
      );

      expect(
        () => dataSource.create(invalidRequest),
        throwsA(isA<RequestAlreadyPersistedException>()),
      );

      final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM requests;'));
      expect(count, equals(0));
    });

    test(
        'create rejects RequestItem with pre-existing item id (item.id != null)',
        () async {
      final pubId = await insertSamplePublication();
      final invalidRequest = Request(
        requestedBy: 'Carlos',
        items: [
          RequestItem(id: 50, publicationId: pubId, quantityRequested: 1),
        ],
      );

      expect(
        () => dataSource.create(invalidRequest),
        throwsA(isA<RequestItemAlreadyPersistedException>()),
      );

      final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM requests;'));
      expect(count, equals(0));
    });

    test('create rejects empty Request (isValidForOrder == false)', () async {
      final emptyRequest = Request(
        requestedBy: 'Carlos',
        items: const [],
      );

      expect(
        () => dataSource.create(emptyRequest),
        throwsA(isA<InvalidRequestForCreationException>()),
      );

      final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM requests;'));
      expect(count, equals(0));
    });

    test('create supports items referencing DRAFT publications (code = null)',
        () async {
      final draftPubId =
          await insertSamplePublication(code: null, name: 'Borrador 1');

      final request = Request(
        requestedBy: 'Pedro',
        items: [
          RequestItem(publicationId: draftPubId, quantityRequested: 3),
        ],
      );

      final persisted = await dataSource.create(request);

      expect(persisted.id, greaterThan(0));
      expect(persisted.items.first.publicationId, equals(draftPubId));
    });

    test('create preserves partial and complete quantityFulfilled', () async {
      final pub1 = await insertSamplePublication(code: 'P1', name: 'Pub 1');
      final pub2 = await insertSamplePublication(code: 'P2', name: 'Pub 2');

      final request = Request(
        requestedBy: 'Lucía',
        items: [
          RequestItem(
              publicationId: pub1, quantityRequested: 5, quantityFulfilled: 2),
          RequestItem(
              publicationId: pub2, quantityRequested: 3, quantityFulfilled: 3),
        ],
      );

      final persisted = await dataSource.create(request);

      expect(persisted.items[0].quantityFulfilled, equals(2));
      expect(persisted.items[1].quantityFulfilled, equals(3));

      final rows = await db.query(DatabaseConstants.tableRequestItems,
          where: 'request_id = ?',
          whereArgs: [persisted.id],
          orderBy: 'id ASC');
      expect(rows[0][DatabaseConstants.columnQuantityFulfilled], equals(2));
      expect(rows[1][DatabaseConstants.columnQuantityFulfilled], equals(3));
    });

    test('create preserves null notes', () async {
      final pubId = await insertSamplePublication();
      final request = Request(
        requestedBy: 'Sofía',
        notes: null,
        items: [RequestItem(publicationId: pubId, quantityRequested: 1)],
      );

      final persisted = await dataSource.create(request);
      expect(persisted.notes, isNull);

      final rows = await db.query(DatabaseConstants.tableRequests,
          where: 'id = ?', whereArgs: [persisted.id]);
      expect(rows.first[DatabaseConstants.columnNotes], isNull);
    });

    test('create supports multiple independent requests with same publication',
        () async {
      final pubId = await insertSamplePublication();

      final reqA = await dataSource.create(Request(
        requestedBy: 'User A',
        items: [RequestItem(publicationId: pubId, quantityRequested: 2)],
      ));

      final reqB = await dataSource.create(Request(
        requestedBy: 'User B',
        items: [RequestItem(publicationId: pubId, quantityRequested: 5)],
      ));

      expect(reqA.id, isNot(equals(reqB.id)));

      final countA = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM request_items WHERE request_id = ?',
          [reqA.id]));
      final countB = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM request_items WHERE request_id = ?',
          [reqB.id]));
      expect(countA, equals(1));
      expect(countB, equals(1));
    });

    test('Atomic Rollback: FK error on item #2 rolls back whole transaction',
        () async {
      final validPubId = await insertSamplePublication();

      final invalidRequest = Request(
        requestedBy: 'Gabriel',
        items: [
          RequestItem(publicationId: validPubId, quantityRequested: 2),
          RequestItem(
              publicationId: 999999, quantityRequested: 1), // Invalid FK
        ],
      );

      // Should throw RequestPersistenceException
      expect(
        () => dataSource.create(invalidRequest),
        throwsA(isA<RequestPersistenceException>()),
      );

      // Confirm ATOMIC ROLLBACK: 0 headers and 0 items persisted!
      final reqCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM requests;'));
      final itemCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM request_items;'));

      expect(reqCount, equals(0));
      expect(itemCount, equals(0));
    });

    test(
        'Prueba A: Persistencia real después de cerrar y reabrir DB física en disco',
        () async {
      final dbPath =
          'test_request_reopen_${DateTime.now().millisecondsSinceEpoch}.db';

      try {
        // 1. Inicializar base física con esquema v2
        await AppDatabase.instance.initDatabaseForTesting(
          dbPath,
          factory: databaseFactoryFfi,
        );
        final localDs =
            RequestLocalDataSourceImpl(appDatabase: AppDatabase.instance);

        // 2. Insertar 3 publicaciones (A: Complete, B: Complete, C: Draft)
        final dbInstance = await AppDatabase.instance.database;
        final nowStr = DateTime.now().toIso8601String();

        final pubA =
            await dbInstance.insert(DatabaseConstants.tablePublications, {
          DatabaseConstants.columnCode: 'PUB-A',
          DatabaseConstants.columnName: 'Publicación A',
          DatabaseConstants.columnType: 'Libro',
          DatabaseConstants.columnCreatedAt: nowStr,
          DatabaseConstants.columnUpdatedAt: nowStr,
        });

        final pubB =
            await dbInstance.insert(DatabaseConstants.tablePublications, {
          DatabaseConstants.columnCode: 'PUB-B',
          DatabaseConstants.columnName: 'Publicación B',
          DatabaseConstants.columnType: 'Folleto',
          DatabaseConstants.columnCreatedAt: nowStr,
          DatabaseConstants.columnUpdatedAt: nowStr,
        });

        final pubC =
            await dbInstance.insert(DatabaseConstants.tablePublications, {
          DatabaseConstants.columnCode: null, // DRAFT
          DatabaseConstants.columnName: 'Publicación Draft C',
          DatabaseConstants.columnType: null,
          DatabaseConstants.columnCreatedAt: nowStr,
          DatabaseConstants.columnUpdatedAt: nowStr,
        });

        final reqCreatedAt = DateTime.now().toUtc();
        final reqUpdatedAt = reqCreatedAt.add(const Duration(minutes: 5));

        final newRequest = Request(
          requestedBy: 'Juan Pérez',
          notes: 'Solicitud de prueba',
          createdAt: reqCreatedAt,
          updatedAt: reqUpdatedAt,
          items: [
            RequestItem(
                publicationId: pubA,
                quantityRequested: 2,
                quantityFulfilled: 0),
            RequestItem(
                publicationId: pubB,
                quantityRequested: 5,
                quantityFulfilled: 2),
            RequestItem(
                publicationId: pubC,
                quantityRequested: 1,
                quantityFulfilled: 1),
          ],
        );

        // 4. Crear request usando la operación productiva create(Request)
        final persistedRequest = await localDs.create(newRequest);

        // 5 y 6. Guardar IDs y valores devueltos
        final expectedRequestId = persistedRequest.id!;
        final expectedItem0Id = persistedRequest.items[0].id!;
        final expectedItem1Id = persistedRequest.items[1].id!;
        final expectedItem2Id = persistedRequest.items[2].id!;

        expect(expectedRequestId, greaterThan(0));
        expect(expectedItem0Id, greaterThan(0));
        expect(expectedItem1Id, greaterThan(0));
        expect(expectedItem2Id, greaterThan(0));

        // 7. Cerrar completamente la conexión SQLite
        await AppDatabase.instance.close();

        // 8. Volver a abrir exactamente el mismo archivo de base de datos
        final reopenedDb = await databaseFactoryFfi.openDatabase(dbPath);

        try {
          // 9 & 10. Consultar directamente mediante SQL 'requests'
          final reqRows = await reopenedDb.query(
            DatabaseConstants.tableRequests,
            where: 'id = ?',
            whereArgs: [expectedRequestId],
          );

          expect(reqRows.length, equals(1));
          final reqRow = reqRows.first;

          expect(reqRow[DatabaseConstants.columnId], equals(expectedRequestId));
          expect(reqRow[DatabaseConstants.columnRequestedBy],
              equals('Juan Pérez'));
          expect(reqRow[DatabaseConstants.columnNotes],
              equals('Solicitud de prueba'));
          expect(reqRow[DatabaseConstants.columnCreatedAt],
              equals(persistedRequest.createdAt.toIso8601String()));
          expect(reqRow[DatabaseConstants.columnUpdatedAt],
              equals(persistedRequest.updatedAt.toIso8601String()));

          // 10. Consultar 'request_items' ordenados determinísticamente por ID
          final itemRows = await reopenedDb.query(
            DatabaseConstants.tableRequestItems,
            where: 'request_id = ?',
            whereArgs: [expectedRequestId],
            orderBy: 'id ASC',
          );

          expect(itemRows.length, equals(3));

          // Verificación de Item 1
          expect(
              itemRows[0][DatabaseConstants.columnId], equals(expectedItem0Id));
          expect(itemRows[0][DatabaseConstants.columnRequestId],
              equals(expectedRequestId));
          expect(
              itemRows[0][DatabaseConstants.columnPublicationId], equals(pubA));
          expect(itemRows[0][DatabaseConstants.columnQuantityRequested],
              equals(2));
          expect(itemRows[0][DatabaseConstants.columnQuantityFulfilled],
              equals(0));

          // Verificación de Item 2
          expect(
              itemRows[1][DatabaseConstants.columnId], equals(expectedItem1Id));
          expect(itemRows[1][DatabaseConstants.columnRequestId],
              equals(expectedRequestId));
          expect(
              itemRows[1][DatabaseConstants.columnPublicationId], equals(pubB));
          expect(itemRows[1][DatabaseConstants.columnQuantityRequested],
              equals(5));
          expect(itemRows[1][DatabaseConstants.columnQuantityFulfilled],
              equals(2));

          // Verificación de Item 3 (Publication Draft)
          expect(
              itemRows[2][DatabaseConstants.columnId], equals(expectedItem2Id));
          expect(itemRows[2][DatabaseConstants.columnRequestId],
              equals(expectedRequestId));
          expect(
              itemRows[2][DatabaseConstants.columnPublicationId], equals(pubC));
          expect(itemRows[2][DatabaseConstants.columnQuantityRequested],
              equals(1));
          expect(itemRows[2][DatabaseConstants.columnQuantityFulfilled],
              equals(1));
        } finally {
          await reopenedDb.close();
        }
      } finally {
        await databaseFactoryFfi.deleteDatabase(dbPath);
      }
    });

    test(
        'Prueba B: Rollback total después de múltiples inserts de renglones válidos',
        () async {
      // 1. Crear un Request A previo válido para comprobar que datos confirmados permanecen intactos
      final pub1 = await insertSamplePublication(code: 'PUB-1', name: 'Pub 1');
      final pub2 = await insertSamplePublication(code: 'PUB-2', name: 'Pub 2');

      final validRequestA = Request(
        requestedBy: 'Solicitud Preexistente A',
        notes: 'Datos confirmados previos',
        items: [
          RequestItem(
              publicationId: pub1, quantityRequested: 10, quantityFulfilled: 0),
        ],
      );

      final persistedReqA = await dataSource.create(validRequestA);
      expect(persistedReqA.id, greaterThan(0));

      // 2. Construir Request B con Item 1 (válido), Item 2 (válido), Item 3 (inexistente FK = 999999)
      final invalidRequestB = Request(
        requestedBy: 'Solicitud Fallida B',
        notes: 'Intento con FK inválida al final',
        items: [
          RequestItem(publicationId: pub1, quantityRequested: 3), // Válido #1
          RequestItem(publicationId: pub2, quantityRequested: 4), // Válido #2
          RequestItem(
              publicationId: 999999, quantityRequested: 1), // Inválido FK #3
        ],
      );

      // 3. Ejecutar create y capturar excepción
      late RequestPersistenceException caughtException;
      try {
        await dataSource.create(invalidRequestB);
        fail(
            'Debió haber lanzado RequestPersistenceException por violación de FK en ítem 3');
      } on RequestPersistenceException catch (e) {
        caughtException = e;
      }

      expect(caughtException, isNotNull);
      expect(caughtException.message, contains('SQLite'));

      // 4. Verificaciones de Rollback en SQLite directo
      // a) No existe la cabecera B en 'requests'
      final reqBRows = await db.query(
        DatabaseConstants.tableRequests,
        where: 'requested_by = ?',
        whereArgs: ['Solicitud Fallida B'],
      );
      expect(reqBRows, isEmpty);

      // b) Ninguno de los 3 renglones de B fue persistido (ni el 1, ni el 2, ni el 3)
      final itemB1Rows = await db.query(
        DatabaseConstants.tableRequestItems,
        where: 'publication_id = ? AND quantity_requested = ?',
        whereArgs: [pub1, 3],
      );
      expect(itemB1Rows, isEmpty);

      final itemB2Rows = await db.query(
        DatabaseConstants.tableRequestItems,
        where: 'publication_id = ? AND quantity_requested = ?',
        whereArgs: [pub2, 4],
      );
      expect(itemB2Rows, isEmpty);

      // c) Total de renglones en la base es únicamente 1 (el de Request A)
      final totalItemsCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM request_items;'),
      );
      expect(totalItemsCount, equals(1));

      final totalReqsCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM requests;'),
      );
      expect(totalReqsCount, equals(1));

      // d) Solicitud Preexistente A sigue 100% intacta
      final reqARows = await db.query(
        DatabaseConstants.tableRequests,
        where: 'id = ?',
        whereArgs: [persistedReqA.id],
      );
      expect(reqARows.length, equals(1));
      expect(reqARows.first[DatabaseConstants.columnRequestedBy],
          equals('Solicitud Preexistente A'));

      // e) Las publicaciones 1 y 2 permanecen intactas en la base
      final pubCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM publications;'),
      );
      expect(pubCount, equals(2));
    });
  });
}
