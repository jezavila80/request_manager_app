import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('Migration v1 to v2 & Reopen SQLite Tests', () {
    test('Migration v1 -> v2 preserves existing publications data and index',
        () async {
      final dbPath =
          'test_migration_v1_v2_${DateTime.now().millisecondsSinceEpoch}.db';

      // 1. Create a database using schema version 1
      final dbV1 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 1,
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
              CREATE UNIQUE INDEX idx_publications_code_unique
              ON publications(code COLLATE NOCASE)
              WHERE code IS NOT NULL AND TRIM(code) <> '';
            ''');
          },
        ),
      );

      final nowStr = DateTime.now().toIso8601String();

      // 2. Insert test publications into v1
      final pubId1 = await dbV1.insert('publications', {
        'code': 'RBI-8',
        'name': 'Biblia Letra Grande',
        'type': 'Libro',
        'is_active': 1,
        'created_at': nowStr,
        'updated_at': nowStr,
      });

      final pubId2 = await dbV1.insert('publications', {
        'code': null,
        'name': 'Borrador especial',
        'type': null,
        'is_active': 1,
        'created_at': nowStr,
        'updated_at': nowStr,
      });

      expect(pubId1, greaterThan(0));
      expect(pubId2, greaterThan(pubId1));

      // Close v1 database
      await dbV1.close();

      // 3. Open database with AppDatabase using version 2 (triggers migration v1 -> v2)
      final dbV2 = await AppDatabase.instance.initDatabaseForTesting(
        dbPath,
        factory: databaseFactoryFfi,
      );

      // Check DB version is updated to 2
      final version = await dbV2.getVersion();
      expect(version, equals(2));

      // 4. Verify existing publications are 100% preserved
      final pubRows = await dbV2.query('publications', orderBy: 'id ASC');
      expect(pubRows.length, equals(2));
      expect(pubRows[0]['code'], equals('RBI-8'));
      expect(pubRows[0]['name'], equals('Biblia Letra Grande'));
      expect(pubRows[1]['code'], isNull);
      expect(pubRows[1]['name'], equals('Borrador especial'));

      // Verify unique index on publications code is still present
      final indexRows = await dbV2.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_publications_code_unique';");
      expect(indexRows.length, equals(1));

      // 5. Verify new tables requests and request_items exist
      final tables = await dbV2.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('requests', 'request_items');");
      expect(tables.length, equals(2));

      // 6. Test inserting into new requests and request_items referencing migrated publications
      final reqId = await dbV2.insert('requests', {
        'requested_by': 'Verónica',
        'created_at': nowStr,
        'updated_at': nowStr,
      });

      final itemId = await dbV2.insert('request_items', {
        'request_id': reqId,
        'publication_id': pubId1,
        'quantity_requested': 10,
      });

      expect(itemId, greaterThan(0));

      // Cleanup
      await AppDatabase.instance.close();
      await databaseFactoryFfi.deleteDatabase(dbPath);
    });

    test(
        'Reopening v2 database maintains version and data without re-migration',
        () async {
      final dbPath =
          'test_reopen_v2_${DateTime.now().millisecondsSinceEpoch}.db';

      // 1. Initialize v2 database
      final db = await AppDatabase.instance.initDatabaseForTesting(
        dbPath,
        factory: databaseFactoryFfi,
      );

      final nowStr = DateTime.now().toIso8601String();
      final pubId = await db.insert('publications', {
        'name': 'Revista Test',
        'created_at': nowStr,
        'updated_at': nowStr,
      });
      final reqId = await db.insert('requests', {
        'requested_by': 'Test User',
        'created_at': nowStr,
        'updated_at': nowStr,
      });
      await db.insert('request_items', {
        'request_id': reqId,
        'publication_id': pubId,
        'quantity_requested': 3,
      });

      await AppDatabase.instance.close();

      // 2. Reopen v2 database
      final dbReopened = await AppDatabase.instance.initDatabaseForTesting(
        dbPath,
        factory: databaseFactoryFfi,
      );

      final version = await dbReopened.getVersion();
      expect(version, equals(2));

      final reqRows = await dbReopened.query('requests');
      expect(reqRows.length, equals(1));
      expect(reqRows.first['requested_by'], equals('Test User'));

      final itemRows = await dbReopened.query('request_items');
      expect(itemRows.length, equals(1));
      expect(itemRows.first['quantity_requested'], equals(3));

      // Cleanup
      await AppDatabase.instance.close();
      await databaseFactoryFfi.deleteDatabase(dbPath);
    });
  });
}
