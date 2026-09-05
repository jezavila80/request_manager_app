import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/core/database/app_database.dart';
import 'package:request_manager_app/core/database/database_constants.dart';
import 'package:request_manager_app/features/publications/data/publication_local_data_source.dart';
import 'package:request_manager_app/features/publications/data/seed/publication_persistence_validation_seed.dart';
import 'package:request_manager_app/features/publications/domain/publication_status.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('PublicationPersistenceValidationSeed Tests', () {
    late Database db;
    late PublicationLocalDataSource dataSource;

    setUp(() async {
      db = await AppDatabase.instance.initDatabaseForTesting(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      dataSource = PublicationLocalDataSource();
    });

    tearDown(() async {
      await AppDatabase.instance.close();
    });

    test('loadSeed inserts 5 demo records and clearSeed deletes only those 5',
        () async {
      // 1. Initial count is 0
      var publications = await dataSource.getAll();
      expect(publications.length, 0);

      // 2. Load seed
      final inserted = await PublicationPersistenceValidationSeed.loadSeed(db);
      expect(inserted, 5);

      publications = await dataSource.getAll();
      expect(publications.length, 5);

      // 3. Verify status mapping (4 COMPLETE, 1 DRAFT)
      final completeCount = publications
          .where((p) => p.status == PublicationStatus.complete)
          .length;
      final draftCount =
          publications.where((p) => p.status == PublicationStatus.draft).length;
      expect(completeCount, 4);
      expect(draftCount, 1);

      // 4. Verify specific items
      final draftItem = publications.firstWhere((p) => p.code == 'mvpfbc2-S');
      expect(draftItem.status, PublicationStatus.draft);
      expect(draftItem.type, isNull);
      expect(draftItem.size.isSinDefinir, isTrue);
      expect(draftItem.version.isNoAplica, isTrue);

      final nwtls = publications.firstWhere((p) => p.code == 'nwtls-S');
      expect(nwtls.status, PublicationStatus.complete);
      expect(nwtls.size.value, 'Grande');
      expect(nwtls.version.value, 'Edición Grande');

      final lffi = publications.firstWhere((p) => p.code == 'lffi-S');
      expect(lffi.status, PublicationStatus.complete);
      expect(lffi.size.isNoAplica, isTrue);
      expect(lffi.version.isNoAplica, isTrue);

      // 5. Idempotency test (calling loadSeed again inserts 0 items)
      final reInserted =
          await PublicationPersistenceValidationSeed.loadSeed(db);
      expect(reInserted, 0);
      expect((await dataSource.getAll()).length, 5);

      // 6. Insert another non-demo publication to test safe cleanup
      await db.insert(DatabaseConstants.tablePublications, {
        DatabaseConstants.columnCode: 'OTHER-01',
        DatabaseConstants.columnName: 'Publicación Real Independiente',
        DatabaseConstants.columnSizeState: DatabaseConstants.stateUndefined,
        DatabaseConstants.columnVersionState: DatabaseConstants.stateUndefined,
        DatabaseConstants.columnIsActive: 1,
        DatabaseConstants.columnCreatedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
      });

      expect((await dataSource.getAll()).length, 6);

      // 7. Clear seed
      final deleted = await PublicationPersistenceValidationSeed.clearSeed(db);
      expect(deleted, 5);

      final remaining = await dataSource.getAll();
      expect(remaining.length, 1);
      expect(remaining.first.code, 'OTHER-01');
    });
  });
}
