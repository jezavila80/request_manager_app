import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:request_manager_app/core/database/app_database.dart';
import 'package:request_manager_app/features/publications/data/publication_local_data_source.dart';
import 'package:request_manager_app/features/publications/domain/publication.dart';
import 'package:request_manager_app/features/publications/domain/publication_exceptions.dart';
import 'package:request_manager_app/features/publications/domain/tri_state_value.dart';

void main() {
  sqfliteFfiInit();

  group('PublicationLocalDataSource SQLite Tests', () {
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

    test('Insert Draft publication successfully and returns positive ID',
        () async {
      final publication = Publication(
        name: 'Biblia Borrador',
        code: null,
      );

      final id = await dataSource.insert(publication);
      expect(id, greaterThan(0));

      final result =
          await db.query('publications', where: 'id = ?', whereArgs: [id]);
      expect(result.length, 1);
      expect(result.first['name'], 'Biblia Borrador');
      expect(result.first['code'], isNull);
    });

    test('Insert Complete publication successfully and returns positive ID',
        () async {
      final publication = Publication(
        name: 'Biblia Letra Grande',
        code: 'RBI-8',
        type: 'Libro',
        size: TriStateValue.conValor('Grande'),
        version: TriStateValue.conValor('Reina Valera'),
        isActive: true,
      );

      final id = await dataSource.insert(publication);
      expect(id, greaterThan(0));

      final result =
          await db.query('publications', where: 'id = ?', whereArgs: [id]);
      expect(result.length, 1);
      expect(result.first['code'], 'RBI-8');
      expect(result.first['size_value'], 'Grande');
      expect(result.first['version_value'], 'Reina Valera');
    });

    test('Multiple Drafts without code does not throw duplicate key error',
        () async {
      final pub1 = Publication(name: 'Draft 1', code: null);
      final pub2 = Publication(name: 'Draft 2', code: null);

      final id1 = await dataSource.insert(pub1);
      final id2 = await dataSource.insert(pub2);

      expect(id1, greaterThan(0));
      expect(id2, greaterThan(id1));
    });

    test(
        'Insert publication with duplicate code throws DuplicatePublicationCodeException',
        () async {
      final pub1 = Publication(name: 'Biblia 1', code: 'RBI-8');
      final pub2 = Publication(
          name: 'Biblia 2', code: 'rbi-8'); // Case-insensitive duplicate

      await dataSource.insert(pub1);

      expect(
        () => dataSource.insert(pub2),
        throwsA(isA<DuplicatePublicationCodeException>()),
      );
    });
  });
}
