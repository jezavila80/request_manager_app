import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:request_manager_app/core/database/app_database.dart';

void main() {
  // Initialize sqflite_common_ffi for testing on the host environment (Windows)
  sqfliteFfiInit();

  group('Publications Schema SQLite Tests', () {
    late Database db;

    setUp(() async {
      // Open an isolated, in-memory database for each test to avoid interference
      db = await AppDatabase.instance.initDatabaseForTesting(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
    });

    tearDown(() async {
      await AppDatabase.instance.close();
    });

    test('Crear base correctamente - la tabla publications existe', () async {
      final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='publications';");
      expect(result, isNotEmpty);
      expect(result.first['name'], 'publications');
    });

    test('Insertar publicación completa con todos los campos válidos',
        () async {
      final createdAt = DateTime.now().toIso8601String();
      final updatedAt = DateTime.now().toIso8601String();

      final id = await db.insert('publications', {
        'code': 'RBI-8',
        'name': 'Biblia Letra Grande',
        'description': 'Una biblia con letra de gran tamaño',
        'type': 'Libro',
        'size_state': 'value',
        'size_value': 'Grande',
        'version_state': 'value',
        'version_value': 'Reina Valera',
        'is_active': 1,
        'created_at': createdAt,
        'updated_at': updatedAt,
      });

      expect(id, greaterThan(0));

      final rows =
          await db.query('publications', where: 'id = ?', whereArgs: [id]);
      expect(rows.length, 1);
      final row = rows.first;
      expect(row['code'], 'RBI-8');
      expect(row['name'], 'Biblia Letra Grande');
      expect(row['description'], 'Una biblia con letra de gran tamaño');
      expect(row['type'], 'Libro');
      expect(row['size_state'], 'value');
      expect(row['size_value'], 'Grande');
      expect(row['version_state'], 'value');
      expect(row['version_value'], 'Reina Valera');
      expect(row['is_active'], 1);
      expect(row['created_at'], createdAt);
      expect(row['updated_at'], updatedAt);
    });

    test('Insertar Draft sin código (code = NULL)', () async {
      final id = await db.insert('publications', {
        'code': null,
        'name': 'Biblia',
        'description': null,
        'type': null,
        'size_state': 'undefined',
        'size_value': null,
        'version_state': 'undefined',
        'version_value': null,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      expect(id, greaterThan(0));
      final rows =
          await db.query('publications', where: 'id = ?', whereArgs: [id]);
      expect(rows.first['code'], isNull);
    });

    test('Insertar múltiples Draft sin código (code = NULL)', () async {
      Future<int> insertDraft() => db.insert('publications', {
            'code': null,
            'name': 'Draft Publication',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

      final id1 = await insertDraft();
      final id2 = await insertDraft();
      final id3 = await insertDraft();

      expect(id1, greaterThan(0));
      expect(id2, greaterThan(id1));
      expect(id3, greaterThan(id2));

      final count = Sqflite.firstIntValue(await db
          .rawQuery('SELECT COUNT(*) FROM publications WHERE code IS NULL'));
      expect(count, 3);
    });

    test('Rechazar nombre vacío', () async {
      expect(
        () => db.insert('publications', {
          'name': '',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('Rechazar nombre solo con espacios', () async {
      expect(
        () => db.insert('publications', {
          'name': '   ',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('Rechazar código duplicado (exacto)', () async {
      await db.insert('publications', {
        'code': 'RBI-8',
        'name': 'Biblia 1',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      expect(
        () => db.insert('publications', {
          'code': 'RBI-8',
          'name': 'Biblia 2',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('Rechazar código duplicado (case-insensitive)', () async {
      await db.insert('publications', {
        'code': 'RBI-8',
        'name': 'Biblia 1',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      expect(
        () => db.insert('publications', {
          'code': 'rbi-8',
          'name': 'Biblia 2',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );

      expect(
        () => db.insert('publications', {
          'code': 'Rbi-8',
          'name': 'Biblia 3',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('size undefined es válido con size_value = NULL', () async {
      final id = await db.insert('publications', {
        'name': 'Biblia',
        'size_state': 'undefined',
        'size_value': null,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      expect(id, greaterThan(0));
    });

    test('size value es válido con size_value no vacío', () async {
      final id = await db.insert('publications', {
        'name': 'Biblia',
        'size_state': 'value',
        'size_value': 'Grande',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      expect(id, greaterThan(0));
    });

    test('size not_applicable es válido con size_value = NULL', () async {
      final id = await db.insert('publications', {
        'name': 'Biblia',
        'size_state': 'not_applicable',
        'size_value': null,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      expect(id, greaterThan(0));
    });

    test('Rechazar size_state = undefined con size_value != NULL', () async {
      expect(
        () => db.insert('publications', {
          'name': 'Biblia',
          'size_state': 'undefined',
          'size_value': 'Grande',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('Rechazar size_state = value con size_value = NULL', () async {
      expect(
        () => db.insert('publications', {
          'name': 'Biblia',
          'size_state': 'value',
          'size_value': null,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('Rechazar size_state = value con size_value solo espacios', () async {
      expect(
        () => db.insert('publications', {
          'name': 'Biblia',
          'size_state': 'value',
          'size_value': '   ',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('version undefined es válido con version_value = NULL', () async {
      final id = await db.insert('publications', {
        'name': 'Biblia',
        'version_state': 'undefined',
        'version_value': null,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      expect(id, greaterThan(0));
    });

    test('version value es válido con version_value no vacío', () async {
      final id = await db.insert('publications', {
        'name': 'Biblia',
        'version_state': 'value',
        'version_value': 'Reina Valera',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      expect(id, greaterThan(0));
    });

    test('version not_applicable es válido con version_value = NULL', () async {
      final id = await db.insert('publications', {
        'name': 'Biblia',
        'version_state': 'not_applicable',
        'version_value': null,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      expect(id, greaterThan(0));
    });

    test('Rechazar version_state = undefined con version_value != NULL',
        () async {
      expect(
        () => db.insert('publications', {
          'name': 'Biblia',
          'version_state': 'undefined',
          'version_value': 'Reina Valera',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('Rechazar version_state = value con version_value = NULL', () async {
      expect(
        () => db.insert('publications', {
          'name': 'Biblia',
          'version_state': 'value',
          'version_value': null,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('Rechazar version_state = value con version_value solo espacios',
        () async {
      expect(
        () => db.insert('publications', {
          'name': 'Biblia',
          'version_state': 'value',
          'version_value': '   ',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('is_active tiene valor por defecto 1', () async {
      final id = await db.insert('publications', {
        'name': 'Biblia',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      final rows =
          await db.query('publications', where: 'id = ?', whereArgs: [id]);
      expect(rows.first['is_active'], 1);
    });

    test('is_active = 0 es válido', () async {
      final id = await db.insert('publications', {
        'name': 'Biblia',
        'is_active': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      final rows =
          await db.query('publications', where: 'id = ?', whereArgs: [id]);
      expect(rows.first['is_active'], 0);
    });

    test('Rechazar is_active con valor inválido (e.g. 2)', () async {
      expect(
        () => db.insert('publications', {
          'name': 'Biblia',
          'is_active': 2,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('fechas se guardan correctamente como texto ISO-8601', () async {
      const nowString = '2026-08-22T17:00:00.000';
      final id = await db.insert('publications', {
        'name': 'Biblia',
        'created_at': nowString,
        'updated_at': nowString,
      });

      final rows =
          await db.query('publications', where: 'id = ?', whereArgs: [id]);
      final row = rows.first;
      expect(row['created_at'], nowString);
      expect(row['updated_at'], nowString);

      // Verify it can be parsed using DateTime.parse
      final parsedCreated = DateTime.parse(row['created_at'] as String);
      final parsedUpdated = DateTime.parse(row['updated_at'] as String);
      expect(parsedCreated.year, 2026);
      expect(parsedCreated.month, 8);
      expect(parsedCreated.day, 22);
      expect(parsedUpdated.year, 2026);
    });

    test('Reabrir base - Conserva schema y datos', () async {
      final dbPath = 'test_reopen_${DateTime.now().millisecondsSinceEpoch}.db';

      // Initialize on a temporary file path
      final dbDisk = await AppDatabase.instance.initDatabaseForTesting(
        dbPath,
        factory: databaseFactoryFfi,
      );

      // Verify table exists
      final tables1 = await dbDisk.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='publications';");
      expect(tables1.length, 1);

      // Insert one row
      await dbDisk.insert('publications', {
        'name': 'Test Reopen',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Close
      await AppDatabase.instance.close();

      // Reopen
      final dbReopened = await AppDatabase.instance.initDatabaseForTesting(
        dbPath,
        factory: databaseFactoryFfi,
      );

      // Check version
      final version = await dbReopened.getVersion();
      expect(version, 1);

      // Check data persists
      final rows = await dbReopened.query('publications');
      expect(rows.length, 1);
      expect(rows.first['name'], 'Test Reopen');

      // Cleanup
      await AppDatabase.instance.close();
      await databaseFactoryFfi.deleteDatabase(dbPath);
    });
  });
}
