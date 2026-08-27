import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:request_manager_app/core/database/app_database.dart';
import 'package:request_manager_app/features/publications/data/publication_repository_impl.dart';
import 'package:request_manager_app/features/publications/domain/publication.dart';
import 'package:request_manager_app/features/publications/domain/publication_exceptions.dart';
import 'package:request_manager_app/features/publications/domain/publication_status.dart';
import 'package:request_manager_app/features/publications/domain/tri_state_value.dart';

void main() {
  sqfliteFfiInit();

  group('PublicationRepositoryImpl Integration Tests', () {
    late PublicationRepositoryImpl repository;

    setUp(() async {
      await AppDatabase.instance.initDatabaseForTesting(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      repository = PublicationRepositoryImpl();
    });

    tearDown(() async {
      await AppDatabase.instance.close();
    });

    test(
        'Success create() of a Draft publication assigns ID and maintains status',
        () async {
      final publication = Publication(
        name: 'Biblia Draft',
        code: null,
      );

      final result = await repository.create(publication);
      expect(result.id, isNotNull);
      expect(result.id, greaterThan(0));
      expect(result.name, 'Biblia Draft');
      expect(result.status, PublicationStatus.draft);
      expect(result.createdAt, publication.createdAt);
    });

    test(
        'Success create() of a Complete publication assigns ID and maintains status',
        () async {
      final publication = Publication(
        name: 'Biblia Completa',
        code: 'RBI-8',
        type: 'Libro',
        size: TriStateValue.conValor('Grande'),
        version: TriStateValue.conValor('Reina Valera'),
      );

      final result = await repository.create(publication);
      expect(result.id, isNotNull);
      expect(result.id, greaterThan(0));
      expect(result.name, 'Biblia Completa');
      expect(result.code, 'RBI-8');
      expect(result.type, 'Libro');
      expect(result.status, PublicationStatus.complete);
    });

    test('Duplicate code propagates DuplicatePublicationCodeException',
        () async {
      final pub1 = Publication(name: 'Biblia 1', code: 'RBI-8');
      final pub2 = Publication(name: 'Biblia 2', code: 'RBI-8');

      await repository.create(pub1);

      expect(
        () => repository.create(pub2),
        throwsA(isA<DuplicatePublicationCodeException>()),
      );
    });

    test('Reject create() when publication already has a non-null ID',
        () async {
      final publication = Publication(
        id: 123,
        name: 'Biblia Existente',
      );

      expect(
        () => repository.create(publication),
        throwsA(isA<PublicationAlreadyPersistedException>()),
      );
    });

    test('Unexpected DB errors are wrapped in PublicationPersistenceException',
        () async {
      // Close the database to trigger an unexpected sqlite exception
      await AppDatabase.instance.close();

      final publication = Publication(name: 'Biblia sin DB');

      expect(
        () => repository.create(publication),
        throwsA(isA<PublicationPersistenceException>()),
      );
    });

    test('getAll() on empty database returns empty list', () async {
      final result = await repository.getAll();
      expect(result, isEmpty);
    });

    test('getById() on non-existing ID returns null', () async {
      final result = await repository.getById(999999);
      expect(result, isNull);
    });

    test('getById() with id <= 0 throws ArgumentError', () async {
      expect(() => repository.getById(0), throwsArgumentError);
      expect(() => repository.getById(-5), throwsArgumentError);
    });

    test(
        'Unexpected DB errors during getAll/getById are wrapped in PublicationPersistenceException',
        () async {
      await AppDatabase.instance.close();

      expect(
        () => repository.getAll(),
        throwsA(isA<PublicationPersistenceException>()),
      );

      expect(
        () => repository.getById(1),
        throwsA(isA<PublicationPersistenceException>()),
      );
    });

    test('Integration: create -> getById -> retrieves the same publication',
        () async {
      final publication = Publication(
        name: 'Integration Test Publication',
        code: 'INT-99',
        type: 'Folleto',
        size: TriStateValue.conValor('Mini'),
        version: TriStateValue.conValor('v1'),
      );

      final created = await repository.create(publication);
      expect(created.id, isNotNull);
      expect(created.id, greaterThan(0));

      final retrieved = await repository.getById(created.id!);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, created.id);
      expect(retrieved.name, 'Integration Test Publication');
      expect(retrieved.code, 'INT-99');
      expect(retrieved.type, 'Folleto');
      expect(retrieved.size.state, TriState.conValor);
      expect(retrieved.size.value, 'Mini');
      expect(retrieved.version.state, TriState.conValor);
      expect(retrieved.version.value, 'v1');
      expect(retrieved.status, PublicationStatus.complete);
    });

    test('Integration: create multiple -> getAll -> returns sorted list',
        () async {
      final pubA = Publication(name: 'Zeta');
      final pubB = Publication(name: 'alfa');
      final pubC = Publication(name: 'Beta');

      final createdA = await repository.create(pubA);
      final createdB = await repository.create(pubB);
      final createdC = await repository.create(pubC);

      final list = await repository.getAll();
      expect(list.length, 3);
      // Expected sorted order (case-insensitive):
      // 1. alfa (createdB)
      // 2. Beta (createdC)
      // 3. Zeta (createdA)
      expect(list[0].id, createdB.id);
      expect(list[0].name, 'alfa');
      expect(list[1].id, createdC.id);
      expect(list[1].name, 'Beta');
      expect(list[2].id, createdA.id);
      expect(list[2].name, 'Zeta');
    });

    test('Integration: persist -> close -> reopen -> verifies persistence',
        () async {
      final dbPath =
          'repo_reopen_test_${DateTime.now().millisecondsSinceEpoch}.db';

      // Initialize repository on temporary database file
      await AppDatabase.instance.initDatabaseForTesting(
        dbPath,
        factory: databaseFactoryFfi,
      );
      final diskRepo = PublicationRepositoryImpl();

      final publication = Publication(
        name: 'Persistent Across Reopen',
        code: 'PAR-1',
        type: 'Libro',
        size: const TriStateValue.noAplica(),
        version: const TriStateValue.noAplica(),
      );

      final created = await diskRepo.create(publication);
      expect(created.id, isNotNull);

      // Close the connection
      await AppDatabase.instance.close();

      // Reopen connection to the same file
      await AppDatabase.instance.initDatabaseForTesting(
        dbPath,
        factory: databaseFactoryFfi,
      );

      // Verify the publication is still there
      final retrieved = await diskRepo.getById(created.id!);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, created.id);
      expect(retrieved.name, 'Persistent Across Reopen');
      expect(retrieved.code, 'PAR-1');
      expect(retrieved.size, const TriStateValue<String>.noAplica());
      expect(retrieved.version, const TriStateValue<String>.noAplica());

      final allList = await diskRepo.getAll();
      expect(allList.length, 1);
      expect(allList.first.id, created.id);

      // Cleanup
      await AppDatabase.instance.close();
      await databaseFactoryFfi.deleteDatabase(dbPath);
    });

    group('searchByName Repository Tests', () {
      test('Successful searchByName returns correct list of publications',
          () async {
        final pub1 = Publication(name: 'Biblia Reina Valera');
        final pub2 = Publication(name: 'Biblia Letra Grande');
        final pub3 = Publication(name: 'Otro Libro');

        await repository.create(pub1);
        await repository.create(pub2);
        await repository.create(pub3);

        final results = await repository.searchByName('biblia');
        expect(results.length, 2);
        expect(results[0].name, 'Biblia Letra Grande'); // sorted alphabetically
        expect(results[1].name, 'Biblia Reina Valera');
      });

      test('Empty query returns empty list', () async {
        final results = await repository.searchByName('   ');
        expect(results, isEmpty);
      });

      test('Invalid limit throws ArgumentError', () async {
        expect(() => repository.searchByName('test', limit: 0),
            throwsArgumentError);
        expect(() => repository.searchByName('test', limit: -1),
            throwsArgumentError);
      });

      test(
          'Unexpected DB errors during searchByName are wrapped in PublicationPersistenceException',
          () async {
        await AppDatabase.instance.close();

        expect(
          () => repository.searchByName('biblia'),
          throwsA(isA<PublicationPersistenceException>()),
        );
      });
    });

    group('searchByCode Repository Tests', () {
      test('Successful searchByCode returns correct list of publications',
          () async {
        final pub1 = Publication(name: 'Biblia 1', code: 'RBI-12');
        final pub2 = Publication(name: 'Biblia 2', code: 'RBI-8');
        final pub3 = Publication(name: 'Otro Libro', code: 'W26-1');

        await repository.create(pub1);
        await repository.create(pub2);
        await repository.create(pub3);

        final results = await repository.searchByCode('RBI');
        expect(results.length, 2);
        expect(results[0].code, 'RBI-12'); // sorted alphabetically
        expect(results[1].code, 'RBI-8');
      });

      test('Empty query returns empty list', () async {
        final results = await repository.searchByCode('   ');
        expect(results, isEmpty);
      });

      test('Invalid limit throws ArgumentError', () async {
        expect(() => repository.searchByCode('test', limit: 0),
            throwsArgumentError);
        expect(() => repository.searchByCode('test', limit: -1),
            throwsArgumentError);
      });

      test('Search excludes inactive publications', () async {
        final active =
            Publication(name: 'Activo', code: 'RBI-8', isActive: true);
        final inactive =
            Publication(name: 'Inactivo', code: 'RBI-9', isActive: false);

        await repository.create(active);
        await repository.create(inactive);

        final results = await repository.searchByCode('RBI');
        expect(results.length, 1);
        expect(results.first.code, 'RBI-8');
      });

      test('Search includes Draft with code but excludes Draft without code',
          () async {
        final draftWithCode = Publication(name: 'Draft con', code: 'RBI-TEMP');
        final draftWithoutCode = Publication(name: 'Draft sin', code: null);

        await repository.create(draftWithCode);
        await repository.create(draftWithoutCode);

        final results = await repository.searchByCode('RBI');
        expect(results.length, 1);
        expect(results.first.code, 'RBI-TEMP');
      });

      test(
          'Unexpected DB errors during searchByCode are wrapped in PublicationPersistenceException',
          () async {
        await AppDatabase.instance.close();

        expect(
          () => repository.searchByCode('RBI'),
          throwsA(isA<PublicationPersistenceException>()),
        );
      });
    });
  });
}
