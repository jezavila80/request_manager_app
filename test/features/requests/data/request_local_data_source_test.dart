import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/core/database/app_database.dart';
import 'package:request_manager_app/core/database/database_constants.dart';
import 'package:request_manager_app/features/publications/domain/publication.dart';
import 'package:request_manager_app/features/requests/data/datasources/request_local_data_source.dart';
import 'package:request_manager_app/features/requests/domain/request.dart';
import 'package:request_manager_app/features/requests/domain/request_exceptions.dart';
import 'package:request_manager_app/features/requests/domain/request_fulfillment_status.dart';
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
      bool isActive = true,
    }) async {
      final nowStr = DateTime.now().toIso8601String();
      return await db.insert(DatabaseConstants.tablePublications, {
        DatabaseConstants.columnCode: code,
        DatabaseConstants.columnName: name,
        DatabaseConstants.columnIsActive: isActive ? 1 : 0,
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

    group('Fase 2.4 — Lectura de solicitudes (getAll & getById)', () {
      test('getAll on empty DB returns empty list', () async {
        final result = await dataSource.getAll();
        expect(result, isEmpty);
        expect(result, isA<List<Request>>());
      });

      test('getById returns null when request is not found', () async {
        final result = await dataSource.getById(999999);
        expect(result, isNull);
      });

      test('getById throws ArgumentError when id <= 0', () async {
        expect(() => dataSource.getById(0), throwsA(isA<ArgumentError>()));
        expect(() => dataSource.getById(-1), throwsA(isA<ArgumentError>()));
      });

      test(
          'getById retrieves single request with 1 item and matches all fields',
          () async {
        final pubId =
            await insertSamplePublication(code: 'PUB-10', name: 'Libro A');
        final now = DateTime.now();

        final created = await dataSource.create(Request(
          requestedBy: 'Ana Gómez',
          notes: 'Nota importante',
          createdAt: now,
          updatedAt: now,
          items: [
            RequestItem(
                publicationId: pubId,
                quantityRequested: 4,
                quantityFulfilled: 1),
          ],
        ));

        final retrieved = await dataSource.getById(created.id!);

        expect(retrieved, isNotNull);
        expect(retrieved!.id, equals(created.id));
        expect(retrieved.requestedBy, equals('Ana Gómez'));
        expect(retrieved.notes, equals('Nota importante'));
        expect(retrieved.createdAt.toIso8601String(),
            equals(now.toIso8601String()));
        expect(retrieved.updatedAt.toIso8601String(),
            equals(now.toIso8601String()));
        expect(retrieved.items.length, equals(1));
        expect(retrieved.items.first.id, equals(created.items.first.id));
        expect(retrieved.items.first.publicationId, equals(pubId));
        expect(retrieved.items.first.quantityRequested, equals(4));
        expect(retrieved.items.first.quantityFulfilled, equals(1));
      });

      test('getById retrieves request with multiple items in id ASC order',
          () async {
        final p1 = await insertSamplePublication(code: 'P-1', name: 'A');
        final p2 = await insertSamplePublication(code: 'P-2', name: 'B');
        final p3 = await insertSamplePublication(code: 'P-3', name: 'C');

        final created = await dataSource.create(Request(
          requestedBy: 'Marcos',
          items: [
            RequestItem(publicationId: p1, quantityRequested: 2),
            RequestItem(publicationId: p2, quantityRequested: 3),
            RequestItem(publicationId: p3, quantityRequested: 5),
          ],
        ));

        final retrieved = await dataSource.getById(created.id!);

        expect(retrieved, isNotNull);
        expect(retrieved!.items.length, equals(3));
        expect(retrieved.items[0].publicationId, equals(p1));
        expect(retrieved.items[1].publicationId, equals(p2));
        expect(retrieved.items[2].publicationId, equals(p3));
        expect(retrieved.items[0].id!, lessThan(retrieved.items[1].id!));
        expect(retrieved.items[1].id!, lessThan(retrieved.items[2].id!));
      });

      test(
          'getAll retrieves multiple requests ordered by created_at DESC, id DESC',
          () async {
        final p = await insertSamplePublication();
        final t1 = DateTime(2026, 1, 1, 10, 0);
        final t2 = DateTime(2026, 1, 2, 10, 0);
        final t3 = DateTime(2026, 1, 3, 10, 0);

        final r1 = await dataSource.create(Request(
          requestedBy: 'Req 1',
          createdAt: t1,
          updatedAt: t1,
          items: [RequestItem(publicationId: p, quantityRequested: 1)],
        ));
        final r2 = await dataSource.create(Request(
          requestedBy: 'Req 2',
          createdAt: t2,
          updatedAt: t2,
          items: [RequestItem(publicationId: p, quantityRequested: 1)],
        ));
        final r3 = await dataSource.create(Request(
          requestedBy: 'Req 3',
          createdAt: t3,
          updatedAt: t3,
          items: [RequestItem(publicationId: p, quantityRequested: 1)],
        ));

        final all = await dataSource.getAll();

        expect(all.length, equals(3));
        expect(all[0].id, equals(r3.id)); // Newest created_at first
        expect(all[1].id, equals(r2.id));
        expect(all[2].id, equals(r1.id));
      });

      test(
          'getAll uses id DESC as tiebreaker when requests have identical createdAt',
          () async {
        final p = await insertSamplePublication();
        final sameTime = DateTime(2026, 5, 10, 12, 0);

        final r1 = await dataSource.create(Request(
          requestedBy: 'Req Same A',
          createdAt: sameTime,
          updatedAt: sameTime,
          items: [RequestItem(publicationId: p, quantityRequested: 1)],
        ));
        final r2 = await dataSource.create(Request(
          requestedBy: 'Req Same B',
          createdAt: sameTime,
          updatedAt: sameTime,
          items: [RequestItem(publicationId: p, quantityRequested: 1)],
        ));

        final all = await dataSource.getAll();

        expect(all.length, equals(2));
        expect(all[0].id, equals(r2.id)); // Higher id first
        expect(all[1].id, equals(r1.id));
      });

      test(
          'getById and getAll support Request referencing DRAFT publication (code = null)',
          () async {
        final draftId =
            await insertSamplePublication(code: null, name: 'Borrador X');

        final created = await dataSource.create(Request(
          requestedBy: 'Laura',
          items: [RequestItem(publicationId: draftId, quantityRequested: 2)],
        ));

        final retrieved = await dataSource.getById(created.id!);
        expect(retrieved, isNotNull);
        expect(retrieved!.items.first.publicationId, equals(draftId));

        final all = await dataSource.getAll();
        expect(all.any((r) => r.id == created.id), isTrue);
      });

      test(
          'getById and getAll support Request referencing INACTIVE publication (isActive = false)',
          () async {
        final inactiveId = await insertSamplePublication(
          code: 'INACT-1',
          name: 'Publicación Inactiva',
          isActive: false,
        );

        final created = await dataSource.create(Request(
          requestedBy: 'Esteban',
          items: [RequestItem(publicationId: inactiveId, quantityRequested: 3)],
        ));

        final retrieved = await dataSource.getById(created.id!);
        expect(retrieved, isNotNull);
        expect(retrieved!.items.first.publicationId, equals(inactiveId));

        final all = await dataSource.getAll();
        expect(all.any((r) => r.id == created.id), isTrue);
      });

      test(
          'getById reconstructs Request without items (items = [], isValidForOrder = false)',
          () async {
        final nowStr = DateTime.now().toIso8601String();
        final emptyHeaderId = await db.insert(DatabaseConstants.tableRequests, {
          DatabaseConstants.columnRequestedBy: 'Sin Renglones',
          DatabaseConstants.columnNotes: 'Solo cabecera',
          DatabaseConstants.columnCreatedAt: nowStr,
          DatabaseConstants.columnUpdatedAt: nowStr,
        });

        final retrieved = await dataSource.getById(emptyHeaderId);

        expect(retrieved, isNotNull);
        expect(retrieved!.id, equals(emptyHeaderId));
        expect(retrieved.items, isEmpty);
        expect(retrieved.isValidForOrder, isFalse);
      });

      test(
          'Physical DB close and reopen: complete aggregate reconstruction via getById and getAll',
          () async {
        final dbPath =
            'test_request_read_reopen_${DateTime.now().millisecondsSinceEpoch}.db';

        try {
          await AppDatabase.instance.initDatabaseForTesting(
            dbPath,
            factory: databaseFactoryFfi,
          );
          final localDs =
              RequestLocalDataSourceImpl(appDatabase: AppDatabase.instance);
          final dbInst = await AppDatabase.instance.database;

          final nowStr = DateTime.now().toIso8601String();
          final pubId =
              await dbInst.insert(DatabaseConstants.tablePublications, {
            DatabaseConstants.columnCode: 'PUB-REOPEN',
            DatabaseConstants.columnName: 'Pub Reopen',
            DatabaseConstants.columnCreatedAt: nowStr,
            DatabaseConstants.columnUpdatedAt: nowStr,
          });

          final reqCreated = DateTime.now().toUtc();
          final reqUpdated = reqCreated.add(const Duration(minutes: 10));

          final created = await localDs.create(Request(
            requestedBy: 'Usuario Reopen',
            notes: 'Nota persistida en disco',
            createdAt: reqCreated,
            updatedAt: reqUpdated,
            items: [
              RequestItem(
                  publicationId: pubId,
                  quantityRequested: 8,
                  quantityFulfilled: 3),
            ],
          ));

          await AppDatabase.instance.close();

          await AppDatabase.instance.initDatabaseForTesting(
            dbPath,
            factory: databaseFactoryFfi,
          );
          final reopenedDs =
              RequestLocalDataSourceImpl(appDatabase: AppDatabase.instance);

          final byId = await reopenedDs.getById(created.id!);
          expect(byId, isNotNull);
          expect(byId!.id, equals(created.id));
          expect(byId.requestedBy, equals('Usuario Reopen'));
          expect(byId.notes, equals('Nota persistida en disco'));
          expect(byId.createdAt.toIso8601String(),
              equals(reqCreated.toIso8601String()));
          expect(byId.updatedAt.toIso8601String(),
              equals(reqUpdated.toIso8601String()));
          expect(byId.items.length, equals(1));
          expect(byId.items.first.quantityRequested, equals(8));
          expect(byId.items.first.quantityFulfilled, equals(3));

          final all = await reopenedDs.getAll();
          expect(all.length, equals(1));
          expect(all.first.id, equals(created.id));
        } finally {
          await AppDatabase.instance.close();
          await databaseFactoryFfi.deleteDatabase(dbPath);
        }
      });

      test(
          'getById preserves exact createdAt and updatedAt timestamps without regenerating',
          () async {
        final p = await insertSamplePublication();
        final createdAt = DateTime.utc(2025, 3, 14, 15, 9, 26);
        final updatedAt = DateTime.utc(2025, 3, 14, 16, 53, 58);

        final created = await dataSource.create(Request(
          requestedBy: 'Timestamp Test',
          createdAt: createdAt,
          updatedAt: updatedAt,
          items: [RequestItem(publicationId: p, quantityRequested: 1)],
        ));

        final retrieved = await dataSource.getById(created.id!);
        expect(retrieved, isNotNull);
        expect(retrieved!.createdAt, equals(createdAt));
        expect(retrieved.updatedAt, equals(updatedAt));
      });

      test('getById preserves null notes', () async {
        final p = await insertSamplePublication();
        final created = await dataSource.create(Request(
          requestedBy: 'Null Notes Test',
          notes: null,
          items: [RequestItem(publicationId: p, quantityRequested: 1)],
        ));

        final retrieved = await dataSource.getById(created.id!);
        expect(retrieved, isNotNull);
        expect(retrieved!.notes, isNull);
      });

      test(
          'getById preserves quantityRequested and quantityFulfilled across fulfillment states',
          () async {
        final p1 =
            await insertSamplePublication(code: 'Q1', name: 'Item Pending');
        final p2 =
            await insertSamplePublication(code: 'Q2', name: 'Item Partial');
        final p3 =
            await insertSamplePublication(code: 'Q3', name: 'Item Fulfilled');

        final created = await dataSource.create(Request(
          requestedBy: 'Quantity Test',
          items: [
            RequestItem(
                publicationId: p1, quantityRequested: 10, quantityFulfilled: 0),
            RequestItem(
                publicationId: p2, quantityRequested: 10, quantityFulfilled: 4),
            RequestItem(
                publicationId: p3,
                quantityRequested: 10,
                quantityFulfilled: 10),
          ],
        ));

        final retrieved = await dataSource.getById(created.id!);
        expect(retrieved, isNotNull);
        expect(retrieved!.items[0].quantityRequested, equals(10));
        expect(retrieved.items[0].quantityFulfilled, equals(0));
        expect(retrieved.items[1].quantityRequested, equals(10));
        expect(retrieved.items[1].quantityFulfilled, equals(4));
        expect(retrieved.items[2].quantityRequested, equals(10));
        expect(retrieved.items[2].quantityFulfilled, equals(10));
      });

      test('fulfillmentStatus is correctly derived from reconstructed items',
          () async {
        final p1 = await insertSamplePublication(code: 'F1', name: 'Pub F1');
        final p2 = await insertSamplePublication(code: 'F2', name: 'Pub F2');

        final pendingReq = await dataSource.create(Request(
          requestedBy: 'Pending Tester',
          items: [
            RequestItem(
                publicationId: p1, quantityRequested: 5, quantityFulfilled: 0)
          ],
        ));

        final partialReq = await dataSource.create(Request(
          requestedBy: 'Partial Tester',
          items: [
            RequestItem(
                publicationId: p1, quantityRequested: 5, quantityFulfilled: 5),
            RequestItem(
                publicationId: p2, quantityRequested: 5, quantityFulfilled: 2),
          ],
        ));

        final fulfilledReq = await dataSource.create(Request(
          requestedBy: 'Fulfilled Tester',
          items: [
            RequestItem(
                publicationId: p1, quantityRequested: 5, quantityFulfilled: 5),
            RequestItem(
                publicationId: p2, quantityRequested: 5, quantityFulfilled: 5),
          ],
        ));

        final readPending = await dataSource.getById(pendingReq.id!);
        final readPartial = await dataSource.getById(partialReq.id!);
        final readFulfilled = await dataSource.getById(fulfilledReq.id!);

        expect(readPending!.fulfillmentStatus,
            equals(RequestFulfillmentStatus.pending));
        expect(readPartial!.fulfillmentStatus,
            equals(RequestFulfillmentStatus.partiallyFulfilled));
        expect(readFulfilled!.fulfillmentStatus,
            equals(RequestFulfillmentStatus.fulfilled));
      });

      test(
          'totalQuantityRequested and totalQuantityFulfilled are correctly derived',
          () async {
        final p1 = await insertSamplePublication(code: 'T1', name: 'T1');
        final p2 = await insertSamplePublication(code: 'T2', name: 'T2');

        final created = await dataSource.create(Request(
          requestedBy: 'Totals Tester',
          items: [
            RequestItem(
                publicationId: p1, quantityRequested: 7, quantityFulfilled: 3),
            RequestItem(
                publicationId: p2,
                quantityRequested: 13,
                quantityFulfilled: 10),
          ],
        ));

        final retrieved = await dataSource.getById(created.id!);
        expect(retrieved, isNotNull);
        expect(retrieved!.totalQuantityRequested, equals(20));
        expect(retrieved.totalQuantityFulfilled, equals(13));
      });

      test(
          'isFullyDefined pure domain evaluation works on reconstructed Request',
          () async {
        final p1 =
            await insertSamplePublication(code: 'FULL-1', name: 'Complete Pub');
        final p2 = await insertSamplePublication(code: null, name: 'Draft Pub');

        final created = await dataSource.create(Request(
          requestedBy: 'Define Tester',
          items: [
            RequestItem(publicationId: p1, quantityRequested: 1),
            RequestItem(publicationId: p2, quantityRequested: 1),
          ],
        ));

        final retrieved = await dataSource.getById(created.id!);
        expect(retrieved, isNotNull);

        final completePub = Publication(
          id: p1,
          code: 'FULL-1',
          name: 'Complete Pub',
          type: 'Libro',
        );
        final draftPub = Publication(
          id: p2,
          code: null,
          name: 'Draft Pub',
        );

        // p2 is draft, so request is not fully defined
        expect(retrieved!.isFullyDefined([completePub, draftPub]), isFalse);

        // If all publications were complete:
        final completePub2 = Publication(
          id: p2,
          code: 'FULL-2',
          name: 'Now Complete Pub',
          type: 'Revista',
        );
        expect(retrieved.isFullyDefined([completePub, completePub2]), isTrue);
      });

      test('original persisted Request matches read Request completely',
          () async {
        final p = await insertSamplePublication(
            code: 'COMP-1', name: 'Comparison Pub');
        final original = await dataSource.create(Request(
          requestedBy: 'Exact Match User',
          notes: 'Comparación idéntica',
          items: [
            RequestItem(
                publicationId: p, quantityRequested: 5, quantityFulfilled: 2)
          ],
        ));

        final retrieved = await dataSource.getById(original.id!);

        expect(retrieved, isNotNull);
        expect(retrieved!.id, equals(original.id));
        expect(retrieved.requestedBy, equals(original.requestedBy));
        expect(retrieved.notes, equals(original.notes));
        expect(retrieved.createdAt, equals(original.createdAt));
        expect(retrieved.updatedAt, equals(original.updatedAt));
        expect(retrieved.items.length, equals(original.items.length));
        expect(retrieved.items.first.id, equals(original.items.first.id));
        expect(retrieved.items.first.publicationId,
            equals(original.items.first.publicationId));
        expect(retrieved.items.first.quantityRequested,
            equals(original.items.first.quantityRequested));
        expect(retrieved.items.first.quantityFulfilled,
            equals(original.items.first.quantityFulfilled));
      });

      test('getAll returns all requests after multiple creates', () async {
        final p = await insertSamplePublication();
        await dataSource.create(Request(
          requestedBy: 'Batch 1',
          items: [RequestItem(publicationId: p, quantityRequested: 1)],
        ));
        await dataSource.create(Request(
          requestedBy: 'Batch 2',
          items: [RequestItem(publicationId: p, quantityRequested: 2)],
        ));
        await dataSource.create(Request(
          requestedBy: 'Batch 3',
          items: [RequestItem(publicationId: p, quantityRequested: 3)],
        ));

        final all = await dataSource.getAll();
        expect(all.length, equals(3));
      });

      test(
          'Corrupted FK: missing referenced publication throws RequestPersistenceException',
          () async {
        final validPubId = await insertSamplePublication();
        final validRequest = await dataSource.create(Request(
          requestedBy: 'Corrupted FK Test',
          items: [RequestItem(publicationId: validPubId, quantityRequested: 2)],
        ));

        // 1. Temporarily disable foreign keys in SQLite test fixture
        await db.execute('PRAGMA foreign_keys = OFF;');

        // 2. Insert invalid item referencing non-existent publication
        await db.insert(DatabaseConstants.tableRequestItems, {
          DatabaseConstants.columnRequestId: validRequest.id,
          DatabaseConstants.columnPublicationId: 999999, // Does not exist!
          DatabaseConstants.columnQuantityRequested: 1,
          DatabaseConstants.columnQuantityFulfilled: 0,
        });

        // 3. Re-enable foreign keys
        await db.execute('PRAGMA foreign_keys = ON;');

        // 4. Assert getById and getAll throw RequestPersistenceException
        expect(
          () => dataSource.getById(validRequest.id!),
          throwsA(isA<RequestPersistenceException>()),
        );
        expect(
          () => dataSource.getAll(),
          throwsA(isA<RequestPersistenceException>()),
        );
      });
    });
  });
}
