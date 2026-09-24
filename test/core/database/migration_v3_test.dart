import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/core/database/app_database.dart';
import 'package:request_manager_app/core/database/database_constants.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('Migration v2 to v3 & Data Consolidation Tests', () {
    test(
        'Migration v2 -> v3 preserves publications, requests, items, and converts requested_by to requester_id',
        () async {
      final dbPath =
          'test_migration_v2_v3_${DateTime.now().millisecondsSinceEpoch}.db';

      // 1. Create a database using schema version 2
      final dbV2 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE publications (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  code TEXT,
                  name TEXT NOT NULL,
                  description TEXT,
                  type TEXT,
                  size_value TEXT,
                  size_state TEXT NOT NULL DEFAULT 'undefined',
                  version_value TEXT,
                  version_state TEXT NOT NULL DEFAULT 'undefined',
                  is_active INTEGER NOT NULL DEFAULT 1,
                  created_at TEXT NOT NULL,
                  updated_at TEXT NOT NULL,
                  CHECK (TRIM(name) <> '')
              );
            ''');

            await db.execute('''
              CREATE TABLE requests (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  requested_by TEXT NOT NULL,
                  notes TEXT,
                  created_at TEXT NOT NULL,
                  updated_at TEXT NOT NULL,
                  CHECK (TRIM(requested_by) <> '')
              );
            ''');

            await db.execute('''
              CREATE TABLE request_items (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  request_id INTEGER NOT NULL,
                  publication_id INTEGER NOT NULL,
                  quantity_requested INTEGER NOT NULL,
                  quantity_fulfilled INTEGER NOT NULL DEFAULT 0,
                  FOREIGN KEY (request_id) REFERENCES requests(id) ON DELETE CASCADE,
                  FOREIGN KEY (publication_id) REFERENCES publications(id) ON DELETE RESTRICT
              );
            ''');
          },
        ),
      );

      final t0 = DateTime.utc(2026, 9, 20, 10, 0).toIso8601String();

      // 2. Insert publications into v2
      final pubId1 = await dbV2.insert('publications', {
        'code': 'PUB-1',
        'name': 'Biblia de Estudio',
        'is_active': 1,
        'created_at': t0,
        'updated_at': t0,
      });

      final pubId2 = await dbV2.insert('publications', {
        'code': 'PUB-2',
        'name': 'Tratado de Paz',
        'is_active': 1,
        'created_at': t0,
        'updated_at': t0,
      });

      // 3. Insert requests into v2
      final reqId1 = await dbV2.insert('requests', {
        'requested_by': 'Carlos Ruiz',
        'notes': 'Nota Carlos',
        'created_at': t0,
        'updated_at': t0,
      });

      final reqId2 = await dbV2.insert('requests', {
        'requested_by': 'Ana Gómez',
        'notes': 'Nota Ana',
        'created_at': t0,
        'updated_at': t0,
      });

      // 4. Insert request items into v2
      final itemId1 = await dbV2.insert('request_items', {
        'request_id': reqId1,
        'publication_id': pubId1,
        'quantity_requested': 5,
        'quantity_fulfilled': 0,
      });

      final itemId2 = await dbV2.insert('request_items', {
        'request_id': reqId2,
        'publication_id': pubId2,
        'quantity_requested': 10,
        'quantity_fulfilled': 2,
      });

      await dbV2.close();

      // 5. Open database with AppDatabase (configured for version 3)
      final dbV3 = await AppDatabase.instance.initDatabaseForTesting(
        dbPath,
        factory: databaseFactoryFfi,
      );

      final version = await dbV3.getVersion();
      expect(version, equals(3));

      // 6. Verify requesters table created with unique normalized_name
      final requesters = await dbV3.query(DatabaseConstants.tableRequesters,
          orderBy: 'id ASC');
      expect(requesters.length, equals(2));
      expect(requesters[0]['name'], equals('Carlos Ruiz'));
      expect(requesters[0]['normalized_name'], equals('carlos ruiz'));
      expect(requesters[1]['name'], equals('Ana Gómez'));
      expect(requesters[1]['normalized_name'], equals('ana gomez'));

      // 7. Verify requests table structure and data
      final reqTableInfo = await dbV3
          .rawQuery('PRAGMA table_info(${DatabaseConstants.tableRequests});');
      final colNames = reqTableInfo.map((c) => c['name'] as String).toSet();
      expect(colNames.contains(DatabaseConstants.columnRequesterId), isTrue);
      expect(colNames.contains(DatabaseConstants.columnRequestedBy), isFalse);

      final requests =
          await dbV3.query(DatabaseConstants.tableRequests, orderBy: 'id ASC');
      expect(requests.length, equals(2));
      expect(requests[0]['id'], equals(reqId1));
      expect(requests[0]['requester_id'], equals(requesters[0]['id']));
      expect(requests[0]['notes'], equals('Nota Carlos'));
      expect(requests[1]['id'], equals(reqId2));
      expect(requests[1]['requester_id'], equals(requesters[1]['id']));
      expect(requests[1]['notes'], equals('Nota Ana'));

      // 8. Verify request_items are completely preserved with original relations
      final items = await dbV3.query(DatabaseConstants.tableRequestItems,
          orderBy: 'id ASC');
      expect(items.length, equals(2));
      expect(items[0]['id'], equals(itemId1));
      expect(items[0]['request_id'], equals(reqId1));
      expect(items[0]['publication_id'], equals(pubId1));
      expect(items[0]['quantity_requested'], equals(5));

      expect(items[1]['id'], equals(itemId2));
      expect(items[1]['request_id'], equals(reqId2));
      expect(items[1]['publication_id'], equals(pubId2));
      expect(items[1]['quantity_requested'], equals(10));

      // 9. Verify foreign keys integrity
      final fkViolations = await dbV3.rawQuery('PRAGMA foreign_key_check;');
      expect(fkViolations, isEmpty);
    });

    test(
        'Special consolidation test: María Soto, Maria Soto, MARIA SOTO converge to single Requester',
        () async {
      final dbPath =
          'test_migration_consolidation_${DateTime.now().millisecondsSinceEpoch}.db';

      final dbV2 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE publications (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  name TEXT NOT NULL,
                  created_at TEXT NOT NULL,
                  updated_at TEXT NOT NULL
              );
            ''');

            await db.execute('''
              CREATE TABLE requests (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  requested_by TEXT NOT NULL,
                  notes TEXT,
                  created_at TEXT NOT NULL,
                  updated_at TEXT NOT NULL
              );
            ''');

            await db.execute('''
              CREATE TABLE request_items (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  request_id INTEGER NOT NULL,
                  publication_id INTEGER NOT NULL,
                  quantity_requested INTEGER NOT NULL,
                  quantity_fulfilled INTEGER NOT NULL DEFAULT 0
              );
            ''');
          },
        ),
      );

      final t0 = DateTime.utc(2026, 9, 21, 10, 0).toIso8601String();

      // Insert Request #1: "María Soto"
      final req1 = await dbV2.insert('requests', {
        'requested_by': 'María Soto',
        'notes': 'Pedido 1',
        'created_at': t0,
        'updated_at': t0,
      });

      // Insert Request #2: "Maria Soto"
      final req2 = await dbV2.insert('requests', {
        'requested_by': 'Maria Soto',
        'notes': 'Pedido 2',
        'created_at': t0,
        'updated_at': t0,
      });

      // Insert Request #3: "MARIA SOTO"
      final req3 = await dbV2.insert('requests', {
        'requested_by': 'MARIA SOTO',
        'notes': 'Pedido 3',
        'created_at': t0,
        'updated_at': t0,
      });

      await dbV2.close();

      // Open in AppDatabase with version 3
      final dbV3 = await AppDatabase.instance.initDatabaseForTesting(
        dbPath,
        factory: databaseFactoryFfi,
      );

      // Verify that requesters count is exactly 1 with normalized_name "maria soto"
      final requesters = await dbV3.query(DatabaseConstants.tableRequesters);
      expect(requesters.length, equals(1));
      expect(requesters.first['normalized_name'], equals('maria soto'));
      // Deterministically preserved the first valid visible representation encountered in id order
      expect(requesters.first['name'], equals('María Soto'));

      final singleRequesterId = requesters.first['id'] as int;

      // Verify all 3 requests point to this exact same requester_id
      final reqRows =
          await dbV3.query(DatabaseConstants.tableRequests, orderBy: 'id ASC');
      expect(reqRows.length, equals(3));
      expect(reqRows[0]['id'], equals(req1));
      expect(reqRows[0]['requester_id'], equals(singleRequesterId));

      expect(reqRows[1]['id'], equals(req2));
      expect(reqRows[1]['requester_id'], equals(singleRequesterId));

      expect(reqRows[2]['id'], equals(req3));
      expect(reqRows[2]['requester_id'], equals(singleRequesterId));

      final fkViolations = await dbV3.rawQuery('PRAGMA foreign_key_check;');
      expect(fkViolations, isEmpty);
    });
  });
}
