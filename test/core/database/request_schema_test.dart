import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/core/database/app_database.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('Request, Requester and RequestItems SQLite Schema v3 Tests', () {
    late Database db;
    late int sampleRequesterId;

    setUp(() async {
      db = await AppDatabase.instance.initDatabaseForTesting(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      final nowStr = DateTime.now().toUtc().toIso8601String();
      sampleRequesterId = await db.insert('requesters', {
        'name': 'Carlos López',
        'normalized_name': 'carlos lopez',
        'is_active': 1,
        'created_at': nowStr,
        'updated_at': nowStr,
      });
    });

    tearDown(() async {
      await AppDatabase.instance.close();
    });

    test(
        'DB v3 creation - tables publications, requesters, requests, request_items exist',
        () async {
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('publications', 'requesters', 'requests', 'request_items');");
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      expect(tableNames.contains('publications'), isTrue);
      expect(tableNames.contains('requesters'), isTrue);
      expect(tableNames.contains('requests'), isTrue);
      expect(tableNames.contains('request_items'), isTrue);
    });

    test('requests table columns verification', () async {
      final info = await db.rawQuery('PRAGMA table_info(requests);');
      final colNames = info.map((c) => c['name'] as String).toSet();

      expect(
        colNames,
        containsAll([
          'id',
          'requester_id',
          'notes',
          'created_at',
          'updated_at',
        ]),
      );
      expect(colNames.contains('requested_by'), isFalse);
    });

    test('request_items table columns verification', () async {
      final info = await db.rawQuery('PRAGMA table_info(request_items);');
      final colNames = info.map((c) => c['name'] as String).toSet();

      expect(
        colNames,
        containsAll([
          'id',
          'request_id',
          'publication_id',
          'quantity_requested',
          'quantity_fulfilled',
        ]),
      );
    });

    group('requests Table Constraints Tests', () {
      test('Insert valid Request header succeeds', () async {
        final nowStr = DateTime.now().toUtc().toIso8601String();
        final reqId = await db.insert('requests', {
          'requester_id': sampleRequesterId,
          'notes': 'Entregar por la tarde',
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        expect(reqId, greaterThan(0));

        final rows =
            await db.query('requests', where: 'id = ?', whereArgs: [reqId]);
        expect(rows.length, equals(1));
        expect(rows.first['requester_id'], equals(sampleRequesterId));
        expect(rows.first['notes'], equals('Entregar por la tarde'));
      });

      test('Rejects NULL or non-existent requester_id', () async {
        final nowStr = DateTime.now().toUtc().toIso8601String();

        // Null requester_id
        expect(
          () => db.insert('requests', {
            'requester_id': null,
            'created_at': nowStr,
            'updated_at': nowStr,
          }),
          throwsA(isA<DatabaseException>()),
        );

        // Non-existent requester_id (FK violation)
        expect(
          () => db.insert('requests', {
            'requester_id': 999999,
            'created_at': nowStr,
            'updated_at': nowStr,
          }),
          throwsA(isA<DatabaseException>()),
        );
      });
    });

    group('request_items Table Constraints & Quantities Tests', () {
      late int sampleReqId;
      late int samplePubId;

      setUp(() async {
        final nowStr = DateTime.now().toUtc().toIso8601String();
        sampleReqId = await db.insert('requests', {
          'requester_id': sampleRequesterId,
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        samplePubId = await db.insert('publications', {
          'name': 'La Atalaya',
          'created_at': nowStr,
          'updated_at': nowStr,
        });
      });

      test(
          'Insert valid RequestItem succeeds with default quantity_fulfilled = 0',
          () async {
        final itemId = await db.insert('request_items', {
          'request_id': sampleReqId,
          'publication_id': samplePubId,
          'quantity_requested': 10,
        });

        expect(itemId, greaterThan(0));

        final rows = await db
            .query('request_items', where: 'id = ?', whereArgs: [itemId]);
        expect(rows.first['quantity_fulfilled'], equals(0));
      });

      test('Rejects quantity_requested <= 0', () async {
        expect(
          () => db.insert('request_items', {
            'request_id': sampleReqId,
            'publication_id': samplePubId,
            'quantity_requested': 0,
          }),
          throwsA(isA<DatabaseException>()),
        );

        expect(
          () => db.insert('request_items', {
            'request_id': sampleReqId,
            'publication_id': samplePubId,
            'quantity_requested': -5,
          }),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('Rejects negative quantity_fulfilled', () async {
        expect(
          () => db.insert('request_items', {
            'request_id': sampleReqId,
            'publication_id': samplePubId,
            'quantity_requested': 5,
            'quantity_fulfilled': -1,
          }),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('Rejects quantity_fulfilled > quantity_requested', () async {
        expect(
          () => db.insert('request_items', {
            'request_id': sampleReqId,
            'publication_id': samplePubId,
            'quantity_requested': 5,
            'quantity_fulfilled': 6,
          }),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('Accepts valid quantity_fulfilled values (0, partial, complete)',
          () async {
        // Pub 1 (0 / 5)
        final id1 = await db.insert('request_items', {
          'request_id': sampleReqId,
          'publication_id': samplePubId,
          'quantity_requested': 5,
          'quantity_fulfilled': 0,
        });
        expect(id1, greaterThan(0));

        // Delete item to re-test different amounts for samplePubId
        await db.delete('request_items', where: 'id = ?', whereArgs: [id1]);

        // Pub 2 (2 / 5)
        final id2 = await db.insert('request_items', {
          'request_id': sampleReqId,
          'publication_id': samplePubId,
          'quantity_requested': 5,
          'quantity_fulfilled': 2,
        });
        expect(id2, greaterThan(0));

        await db.delete('request_items', where: 'id = ?', whereArgs: [id2]);

        // Pub 3 (5 / 5)
        final id3 = await db.insert('request_items', {
          'request_id': sampleReqId,
          'publication_id': samplePubId,
          'quantity_requested': 5,
          'quantity_fulfilled': 5,
        });
        expect(id3, greaterThan(0));
      });
    });

    group('Foreign Keys & Cascade / Restrict Policies Tests', () {
      test('Rejects item with non-existent request_id (FK constraint)',
          () async {
        final nowStr = DateTime.now().toUtc().toIso8601String();
        final pubId = await db.insert('publications', {
          'name': '¡Despertad!',
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        expect(
          () => db.insert('request_items', {
            'request_id': 999999, // Inexistent request
            'publication_id': pubId,
            'quantity_requested': 5,
          }),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('Rejects item with non-existent publication_id (FK constraint)',
          () async {
        final nowStr = DateTime.now().toUtc().toIso8601String();
        final reqId = await db.insert('requests', {
          'requester_id': sampleRequesterId,
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        expect(
          () => db.insert('request_items', {
            'request_id': reqId,
            'publication_id': 999999, // Inexistent publication
            'quantity_requested': 5,
          }),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('Allows item referencing a DRAFT publication', () async {
        final nowStr = DateTime.now().toUtc().toIso8601String();
        final reqId = await db.insert('requests', {
          'requester_id': sampleRequesterId,
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        // Insert DRAFT Publication (code is NULL)
        final draftPubId = await db.insert('publications', {
          'code': null,
          'name': 'Borrador rápido especial',
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        final itemId = await db.insert('request_items', {
          'request_id': reqId,
          'publication_id': draftPubId,
          'quantity_requested': 1,
        });

        expect(itemId, greaterThan(0));
      });

      test(
          'ON DELETE CASCADE: Deleting Request deletes its child request_items',
          () async {
        final nowStr = DateTime.now().toUtc().toIso8601String();
        final reqId = await db.insert('requests', {
          'requester_id': sampleRequesterId,
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        final pub1 = await db.insert('publications', {
          'name': 'Pub A',
          'created_at': nowStr,
          'updated_at': nowStr,
        });
        final pub2 = await db.insert('publications', {
          'name': 'Pub B',
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        await db.insert('request_items', {
          'request_id': reqId,
          'publication_id': pub1,
          'quantity_requested': 2,
        });
        await db.insert('request_items', {
          'request_id': reqId,
          'publication_id': pub2,
          'quantity_requested': 4,
        });

        final countBefore = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM request_items WHERE request_id = ?',
            [reqId]));
        expect(countBefore, equals(2));

        // Delete parent request
        await db.delete('requests', where: 'id = ?', whereArgs: [reqId]);

        final countAfter = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM request_items WHERE request_id = ?',
            [reqId]));
        expect(countAfter, equals(0));
      });

      test(
          'ON DELETE RESTRICT: Deleting referenced Publication is rejected by SQLite',
          () async {
        final nowStr = DateTime.now().toUtc().toIso8601String();
        final reqId = await db.insert('requests', {
          'requester_id': sampleRequesterId,
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        final pubId = await db.insert('publications', {
          'name': 'Biblia',
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        await db.insert('request_items', {
          'request_id': reqId,
          'publication_id': pubId,
          'quantity_requested': 3,
        });

        // Attempt to delete referenced publication must fail due to ON DELETE RESTRICT
        expect(
          () => db.delete('publications', where: 'id = ?', whereArgs: [pubId]),
          throwsA(isA<DatabaseException>()),
        );

        // Confirm publication remains untouched
        final pubRows =
            await db.query('publications', where: 'id = ?', whereArgs: [pubId]);
        expect(pubRows.length, equals(1));
      });

      test(
          'ON DELETE RESTRICT: Deleting referenced Requester is rejected by SQLite',
          () async {
        final nowStr = DateTime.now().toUtc().toIso8601String();
        await db.insert('requests', {
          'requester_id': sampleRequesterId,
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        expect(
          () => db.delete('requesters',
              where: 'id = ?', whereArgs: [sampleRequesterId]),
          throwsA(isA<DatabaseException>()),
        );
      });
    });

    group('Uniqueness & Publication Replacement Tests', () {
      test(
          'UNIQUE(request_id, publication_id) rejects duplicate publication in same request',
          () async {
        final nowStr = DateTime.now().toUtc().toIso8601String();
        final reqId = await db.insert('requests', {
          'requester_id': sampleRequesterId,
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        final pubId = await db.insert('publications', {
          'name': 'Revista A',
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        await db.insert('request_items', {
          'request_id': reqId,
          'publication_id': pubId,
          'quantity_requested': 5,
        });

        // Inserting second item with same request_id and publication_id must fail
        expect(
          () => db.insert('request_items', {
            'request_id': reqId,
            'publication_id': pubId,
            'quantity_requested': 2,
          }),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('Same publication_id in DIFFERENT requests is allowed', () async {
        final nowStr = DateTime.now().toUtc().toIso8601String();
        final req1 = await db.insert('requests', {
          'requester_id': sampleRequesterId,
          'created_at': nowStr,
          'updated_at': nowStr,
        });
        final req2 = await db.insert('requests', {
          'requester_id': sampleRequesterId,
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        final pubId = await db.insert('publications', {
          'name': 'Revista B',
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        final item1 = await db.insert('request_items', {
          'request_id': req1,
          'publication_id': pubId,
          'quantity_requested': 5,
        });
        final item2 = await db.insert('request_items', {
          'request_id': req2,
          'publication_id': pubId,
          'quantity_requested': 3,
        });

        expect(item1, greaterThan(0));
        expect(item2, greaterThan(item1));
      });

      test(
          'Replaces Draft publication_id with Complete publication_id preserving item identity and quantities',
          () async {
        final nowStr = DateTime.now().toUtc().toIso8601String();
        final reqId = await db.insert('requests', {
          'requester_id': sampleRequesterId,
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        final draftPubId = await db.insert('publications', {
          'code': null,
          'name': 'Borrador 35',
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        final completePubId = await db.insert('publications', {
          'code': 'RL-12',
          'name': 'Revista La Atalaya Complete',
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        final itemId = await db.insert('request_items', {
          'request_id': reqId,
          'publication_id': draftPubId,
          'quantity_requested': 10,
          'quantity_fulfilled': 4,
        });

        // Update item 103: publication_id draft -> complete
        final updatedRows = await db.update(
          'request_items',
          {'publication_id': completePubId},
          where: 'id = ?',
          whereArgs: [itemId],
        );
        expect(updatedRows, equals(1));

        final itemRows = await db
            .query('request_items', where: 'id = ?', whereArgs: [itemId]);
        final itemRow = itemRows.first;
        expect(itemRow['id'], equals(itemId));
        expect(itemRow['request_id'], equals(reqId));
        expect(itemRow['publication_id'], equals(completePubId));
        expect(itemRow['quantity_requested'], equals(10));
        expect(itemRow['quantity_fulfilled'], equals(4));
      });

      test(
          'Replaces publication_id with collision rejected by UNIQUE constraint',
          () async {
        final nowStr = DateTime.now().toUtc().toIso8601String();
        final reqId = await db.insert('requests', {
          'requester_id': sampleRequesterId,
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        final pub8 = await db.insert('publications', {
          'code': 'PUB-8',
          'name': 'Pub 8',
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        final pub35Draft = await db.insert('publications', {
          'code': null,
          'name': 'Draft 35',
          'created_at': nowStr,
          'updated_at': nowStr,
        });

        // Item 1: Pub 8
        await db.insert('request_items', {
          'request_id': reqId,
          'publication_id': pub8,
          'quantity_requested': 5,
        });

        // Item 2: Draft 35
        final item2 = await db.insert('request_items', {
          'request_id': reqId,
          'publication_id': pub35Draft,
          'quantity_requested': 10,
        });

        // Attempting to update Item 2 publication_id 35 -> 8 must fail because Pub 8 is already in reqId
        expect(
          () => db.update(
            'request_items',
            {'publication_id': pub8},
            where: 'id = ?',
            whereArgs: [item2],
          ),
          throwsA(isA<DatabaseException>()),
        );
      });
    });
  });
}
