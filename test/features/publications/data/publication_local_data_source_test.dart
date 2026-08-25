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

    test('getAll() on empty database returns empty list', () async {
      final result = await dataSource.getAll();
      expect(result, isEmpty);
    });

    test('getById() on non-existing ID returns null', () async {
      final result = await dataSource.getById(999999);
      expect(result, isNull);
    });

    test('getById() with id <= 0 throws ArgumentError', () async {
      expect(() => dataSource.getById(0), throwsArgumentError);
      expect(() => dataSource.getById(-1), throwsArgumentError);
    });

    test('Insert and getById retrieves exact Draft publication', () async {
      final publication = Publication(
        name: 'Draft Test',
        description: 'Borrador descriptivo',
      );

      final id = await dataSource.insert(publication);
      final retrieved = await dataSource.getById(id);

      expect(retrieved, isNotNull);
      expect(retrieved!.id, id);
      expect(retrieved.name, 'Draft Test');
      expect(retrieved.description, 'Borrador descriptivo');
      expect(retrieved.code, isNull);
      expect(retrieved.type, isNull);
      expect(retrieved.size, const TriStateValue<String>.sinDefinir());
      expect(retrieved.version, const TriStateValue<String>.sinDefinir());
      expect(retrieved.isActive, isTrue);
      expect(
          retrieved.createdAt.isAtSameMomentAs(publication.createdAt), isTrue);
      expect(
          retrieved.updatedAt.isAtSameMomentAs(publication.updatedAt), isTrue);
    });

    test(
        'Insert and getById retrieves exact Complete publication with TriState values and isActive=false',
        () async {
      final now = DateTime.now();
      final publication = Publication(
        name: 'Complete Test',
        code: 'COMP-1',
        type: 'Tratado',
        size: TriStateValue.conValor('Mediano'),
        version: TriStateValue.conValor('v2'),
        isActive: false,
        createdAt: now,
        updatedAt: now,
      );

      final id = await dataSource.insert(publication);
      final retrieved = await dataSource.getById(id);

      expect(retrieved, isNotNull);
      expect(retrieved!.id, id);
      expect(retrieved.name, 'Complete Test');
      expect(retrieved.code, 'COMP-1');
      expect(retrieved.type, 'Tratado');
      expect(retrieved.size.state, TriState.conValor);
      expect(retrieved.size.value, 'Mediano');
      expect(retrieved.version.state, TriState.conValor);
      expect(retrieved.version.value, 'v2');
      expect(retrieved.isActive, isFalse);
      expect(retrieved.createdAt.isAtSameMomentAs(now), isTrue);
      expect(retrieved.updatedAt.isAtSameMomentAs(now), isTrue);
    });

    test('Insert and getById roundtrips size/version not_applicable', () async {
      final publication = Publication(
        name: 'Not Applicable Test',
        size: const TriStateValue.noAplica(),
        version: const TriStateValue.noAplica(),
      );

      final id = await dataSource.insert(publication);
      final retrieved = await dataSource.getById(id);

      expect(retrieved, isNotNull);
      expect(retrieved!.size, const TriStateValue<String>.noAplica());
      expect(retrieved.version, const TriStateValue<String>.noAplica());
    });

    test(
        'getAll() returns all publications sorted by name COLLATE NOCASE ASC, and secondary id ASC',
        () async {
      final pub1 = Publication(name: 'revistilla');
      final pub2 = Publication(name: 'Biblia');
      final pub3 = Publication(name: 'Folleto');
      final pub4 = Publication(
          name: 'Biblia'); // Duplicate name to test secondary sort by ID

      final id1 = await dataSource.insert(pub1);
      final id2 = await dataSource.insert(pub2);
      final id3 = await dataSource.insert(pub3);
      final id4 = await dataSource.insert(pub4);

      final list = await dataSource.getAll();
      expect(list.length, 4);

      // Expected sorted order case-insensitive:
      // 1. Biblia (id2)
      // 2. Biblia (id4) -- secondary sort
      // 3. Folleto (id3)
      // 4. revistilla (id1)
      expect(list[0].id, id2);
      expect(list[0].name, 'Biblia');

      expect(list[1].id, id4);
      expect(list[1].name, 'Biblia');

      expect(list[2].id, id3);
      expect(list[2].name, 'Folleto');

      expect(list[3].id, id1);
      expect(list[3].name, 'revistilla');
    });
  });
}
