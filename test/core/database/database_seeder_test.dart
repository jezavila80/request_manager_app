import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/core/database/app_database.dart';
import 'package:request_manager_app/core/database/database_constants.dart';
import 'package:request_manager_app/core/database/database_seeder.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseSeeder Tests', () {
    test('Seeds 14 initial publication test records when table is empty',
        () async {
      final db = await AppDatabase.instance.initDatabaseForTesting(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );

      // Verify empty initial state before seeding
      var countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseConstants.tablePublications}',
      );
      expect(Sqflite.firstIntValue(countResult), 0);

      // Seed publications
      await DatabaseSeeder.seedIfEmpty(db);

      countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseConstants.tablePublications}',
      );
      expect(Sqflite.firstIntValue(countResult), 14);

      // Verify idempotency (calling seedIfEmpty again does not duplicate items)
      await DatabaseSeeder.seedIfEmpty(db);

      countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseConstants.tablePublications}',
      );
      expect(Sqflite.firstIntValue(countResult), 14);

      await AppDatabase.instance.close();
    });
  });
}
