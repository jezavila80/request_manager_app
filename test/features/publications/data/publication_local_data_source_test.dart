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

    group('searchByName Tests', () {
      test(
          'Empty or whitespace query returns empty list without querying database',
          () async {
        final r1 = await dataSource.searchByName('');
        final r2 = await dataSource.searchByName('    ');
        expect(r1, isEmpty);
        expect(r2, isEmpty);
      });

      test('Invalid limit throws ArgumentError', () async {
        expect(() => dataSource.searchByName('test', limit: 0),
            throwsArgumentError);
        expect(() => dataSource.searchByName('test', limit: -5),
            throwsArgumentError);
      });

      test('Search excludes inactive publications', () async {
        final active = Publication(name: 'Biblia Activa', isActive: true);
        final inactive = Publication(name: 'Biblia Inactiva', isActive: false);

        await dataSource.insert(active);
        await dataSource.insert(inactive);

        final results = await dataSource.searchByName('biblia');
        expect(results.length, 1);
        expect(results.first.name, 'Biblia Activa');
      });

      test('Search includes both DRAFT and COMPLETE publications', () async {
        final draft = Publication(
            name: 'Biblia Borrador', code: null, type: null); // Draft status
        final complete = Publication(
            name: 'Biblia Completa',
            code: 'BC-1',
            type: 'Libro'); // Complete status

        await dataSource.insert(draft);
        await dataSource.insert(complete);

        final results = await dataSource.searchByName('biblia');
        expect(results.length, 2);

        final names = results.map((e) => e.name).toList();
        expect(names, containsAll(['Biblia Borrador', 'Biblia Completa']));
      });

      test('Search is case-insensitive', () async {
        final pub = Publication(name: 'BiBlIa ReInA');
        await dataSource.insert(pub);

        final r1 = await dataSource.searchByName('biblia');
        final r2 = await dataSource.searchByName('BIBLIA');
        final r3 = await dataSource.searchByName('BiBlIa');

        expect(r1.length, 1);
        expect(r2.length, 1);
        expect(r3.length, 1);
        expect(r1.first.name, 'BiBlIa ReInA');
      });

      test('Search trims query whitespace', () async {
        final pub = Publication(name: 'Biblia');
        await dataSource.insert(pub);

        final results = await dataSource.searchByName('   biblia   ');
        expect(results.length, 1);
        expect(results.first.name, 'Biblia');
      });

      test('Search respects limit and defaults to 20', () async {
        for (int i = 0; i < 25; i++) {
          await dataSource.insert(Publication(name: 'Biblia $i'));
        }

        final defaultLimitResults = await dataSource.searchByName('biblia');
        expect(defaultLimitResults.length, 20);

        final customLimitResults =
            await dataSource.searchByName('biblia', limit: 5);
        expect(customLimitResults.length, 5);
      });

      test(
          'Search ranks exactMatch -> startsWith -> contains, then alphabetical, then ID',
          () async {
        final pub1 = Publication(name: 'Manual sobre la Biblia'); // contains
        final pub2 = Publication(name: 'Biblia'); // exact
        final pub3 = Publication(name: 'Santa Biblia de bolsillo'); // contains
        final pub4 = Publication(name: 'Biblia Reina Valera'); // startsWith
        final pub5 = Publication(name: 'Biblia Letra Grande'); // startsWith

        await dataSource.insert(pub1);
        final exactId = await dataSource.insert(pub2);
        await dataSource.insert(pub3);
        final sw2Id = await dataSource.insert(pub4);
        final sw1Id = await dataSource.insert(pub5);

        final results = await dataSource.searchByName('biblia');
        expect(results.length, 5);

        // Expected Order:
        // 1. Biblia (exact)
        // 2. Biblia Letra Grande (startsWith, sorted alphabetically before Biblia Reina Valera)
        // 3. Biblia Reina Valera (startsWith)
        // 4. Manual sobre la Biblia (contains, sorted alphabetically before Santa Biblia)
        // 5. Santa Biblia de bolsillo (contains)

        expect(results[0].id, exactId);
        expect(results[0].name, 'Biblia');

        expect(results[1].id, sw1Id);
        expect(results[1].name, 'Biblia Letra Grande');

        expect(results[2].id, sw2Id);
        expect(results[2].name, 'Biblia Reina Valera');

        expect(results[3].name, 'Manual sobre la Biblia');
        expect(results[4].name, 'Santa Biblia de bolsillo');
      });

      test('Search escapes LIKE wildcard characters %, _ and \\ safely',
          () async {
        final matchPercent = Publication(name: 'Manual 100%');
        final nonMatchPercent = Publication(name: 'Manual 100a');
        final matchUnderscore = Publication(name: 'Manual_Especial');
        final nonMatchUnderscore = Publication(name: 'ManualXEspecial');
        final matchBackslash = Publication(name: 'Manual\\Backslash');

        await dataSource.insert(matchPercent);
        await dataSource.insert(nonMatchPercent);
        await dataSource.insert(matchUnderscore);
        await dataSource.insert(nonMatchUnderscore);
        await dataSource.insert(matchBackslash);

        // Search '%' literally
        final resPercent = await dataSource.searchByName('100%');
        expect(resPercent.length, 1);
        expect(resPercent.first.name, 'Manual 100%');

        // Search '_' literally
        final resUnderscore = await dataSource.searchByName('Manual_');
        expect(resUnderscore.length, 1);
        expect(resUnderscore.first.name, 'Manual_Especial');

        // Search '\' literally
        final resBackslash = await dataSource.searchByName('Manual\\');
        expect(resBackslash.length, 1);
        expect(resBackslash.first.name, 'Manual\\Backslash');
      });
    });

    group('searchByCode Tests', () {
      test(
          'Empty or whitespace query returns empty list without querying database',
          () async {
        final r1 = await dataSource.searchByCode('');
        final r2 = await dataSource.searchByCode('    ');
        expect(r1, isEmpty);
        expect(r2, isEmpty);
      });

      test('Invalid limit throws ArgumentError', () async {
        expect(() => dataSource.searchByCode('test', limit: 0),
            throwsArgumentError);
        expect(() => dataSource.searchByCode('test', limit: -5),
            throwsArgumentError);
      });

      test('Search excludes inactive publications', () async {
        final active =
            Publication(name: 'Biblia Activa', code: 'RBI-8', isActive: true);
        final inactive = Publication(
            name: 'Biblia Inactiva', code: 'RBI-9', isActive: false);

        await dataSource.insert(active);
        await dataSource.insert(inactive);

        final results = await dataSource.searchByCode('RBI');
        expect(results.length, 1);
        expect(results.first.name, 'Biblia Activa');
      });

      test('Search includes both DRAFT with code and COMPLETE publications',
          () async {
        final draftWithCode = Publication(
            name: 'Biblia Borrador',
            code: 'RBI-TEMP',
            type: null); // Draft status
        final draftWithoutCode = Publication(
            name: 'Biblia Borrador 2',
            code: null,
            type: null); // Draft status, no code
        final complete = Publication(
            name: 'Biblia Completa',
            code: 'RBI-8',
            type: 'Libro'); // Complete status

        await dataSource.insert(draftWithCode);
        await dataSource.insert(draftWithoutCode);
        await dataSource.insert(complete);

        final results = await dataSource.searchByCode('RBI');
        expect(results.length, 2);

        final codes = results.map((e) => e.code).toList();
        expect(codes, containsAll(['RBI-TEMP', 'RBI-8']));
        expect(codes, isNot(contains(null)));
      });

      test('Search is case-insensitive', () async {
        final pub = Publication(name: 'Biblia Reina', code: 'RbI-8');
        await dataSource.insert(pub);

        final r1 = await dataSource.searchByCode('rbi-8');
        final r2 = await dataSource.searchByCode('RBI-8');
        final r3 = await dataSource.searchByCode('RbI-8');

        expect(r1.length, 1);
        expect(r2.length, 1);
        expect(r3.length, 1);
        expect(r1.first.code, 'RbI-8');
      });

      test('Search trims query whitespace', () async {
        final pub = Publication(name: 'Biblia', code: 'RBI-8');
        await dataSource.insert(pub);

        final results = await dataSource.searchByCode('   rbi-8   ');
        expect(results.length, 1);
        expect(results.first.code, 'RBI-8');
      });

      test('Search respects limit and defaults to 20', () async {
        for (int i = 0; i < 25; i++) {
          await dataSource.insert(Publication(name: 'Biblia $i', code: 'R-$i'));
        }

        final defaultLimitResults = await dataSource.searchByCode('R');
        expect(defaultLimitResults.length, 20);

        final customLimitResults = await dataSource.searchByCode('R', limit: 5);
        expect(customLimitResults.length, 5);
      });

      test(
          'Search ranks exactMatch -> startsWith -> contains, then alphabetical, then ID',
          () async {
        final pub1 = Publication(name: 'Contains 1', code: 'XRBI-1');
        final pub2 = Publication(name: 'Exact', code: 'RBI');
        final pub3 = Publication(name: 'Contains 2', code: 'A-RBI-2');
        final pub4 = Publication(name: 'StartsWith 1', code: 'RBI-12');
        final pub5 = Publication(name: 'StartsWith 2', code: 'RBI-8');

        final id1 = await dataSource.insert(pub1);
        final id2 = await dataSource.insert(pub2);
        final id3 = await dataSource.insert(pub3);
        final id4 = await dataSource.insert(pub4);
        final id5 = await dataSource.insert(pub5);

        final results = await dataSource.searchByCode('RBI');
        expect(results.length, 5);

        // Expected sorted order:
        // 1. RBI (exact)
        // 2. RBI-12 (startsWith, sorted alphabetically before RBI-8)
        // 3. RBI-8 (startsWith)
        // 4. A-RBI-2 (contains, sorted alphabetically before XRBI-1)
        // 5. XRBI-1 (contains)
        expect(results[0].id, id2);
        expect(results[0].code, 'RBI');

        expect(results[1].id, id4);
        expect(results[1].code, 'RBI-12');

        expect(results[2].id, id5);
        expect(results[2].code, 'RBI-8');

        expect(results[3].id, id3);
        expect(results[3].code, 'A-RBI-2');

        expect(results[4].id, id1);
        expect(results[4].code, 'XRBI-1');
      });

      test('Search escapes LIKE wildcard characters %, _ and \\ safely',
          () async {
        final matchPercent = Publication(name: 'Percent', code: 'RBI%8');
        final nonMatchPercent = Publication(name: 'Percent No', code: 'RBI88');
        final matchUnderscore = Publication(name: 'Underscore', code: 'RBI_8');
        final nonMatchUnderscore =
            Publication(name: 'Underscore No', code: 'RBIA8');
        final matchBackslash = Publication(name: 'Backslash', code: 'RBI\\8');

        await dataSource.insert(matchPercent);
        await dataSource.insert(nonMatchPercent);
        await dataSource.insert(matchUnderscore);
        await dataSource.insert(nonMatchUnderscore);
        await dataSource.insert(matchBackslash);

        // Search '%' literally
        final resPercent = await dataSource.searchByCode('RBI%');
        expect(resPercent.length, 1);
        expect(resPercent.first.code, 'RBI%8');

        // Search '_' literally
        final resUnderscore = await dataSource.searchByCode('RBI_');
        expect(resUnderscore.length, 1);
        expect(resUnderscore.first.code, 'RBI_8');

        // Search '\' literally
        final resBackslash = await dataSource.searchByCode('RBI\\');
        expect(resBackslash.length, 1);
        expect(resBackslash.first.code, 'RBI\\8');
      });
    });

    group('findActiveByExactCode and findActiveByName Tests', () {
      test('findActiveByExactCode returns exact publication case-insensitive',
          () async {
        final active =
            Publication(name: 'Biblia 1', code: 'RBI-8', isActive: true);
        await dataSource.insert(active);

        final r1 = await dataSource.findActiveByExactCode('rbi-8');
        final r2 = await dataSource.findActiveByExactCode('RBI-8');
        final r3 = await dataSource.findActiveByExactCode('Rbi-8');

        expect(r1, isNotNull);
        expect(r1!.code, 'RBI-8');
        expect(r2, isNotNull);
        expect(r2!.code, 'RBI-8');
        expect(r3, isNotNull);
        expect(r3!.code, 'RBI-8');
      });

      test('findActiveByExactCode returns null for nonexistent code', () async {
        final result = await dataSource.findActiveByExactCode('NONEXISTENT');
        expect(result, isNull);
      });

      test('findActiveByExactCode excludes inactive publications', () async {
        final inactive = Publication(
            name: 'Biblia Inactiva', code: 'RBI-8', isActive: false);
        await dataSource.insert(inactive);

        final result = await dataSource.findActiveByExactCode('RBI-8');
        expect(result, isNull);
      });

      test('findActiveByExactCode throws ArgumentError on empty code',
          () async {
        expect(() => dataSource.findActiveByExactCode(''), throwsArgumentError);
        expect(
            () => dataSource.findActiveByExactCode('   '), throwsArgumentError);
      });

      test(
          'findActiveByName returns exact matches case-insensitive sorted by name COLLATE NOCASE ASC, id ASC',
          () async {
        final p1 = Publication(
            name: 'Biblia Letra Grande', code: 'P1', isActive: true);
        final p2 = Publication(
            name: 'biblia letra grande', code: 'P2', isActive: true);
        final p3 = Publication(
            name: 'Biblia Letra Chica',
            code: 'P3',
            isActive: true); // different name

        final id1 = await dataSource.insert(p1);
        final id2 = await dataSource.insert(p2);
        await dataSource.insert(p3);

        final results =
            await dataSource.findActiveByName('  Biblia Letra Grande  ');
        expect(results.length, 2);
        expect(results[0].id, id1);
        expect(results[1].id, id2);
      });

      test('findActiveByName excludes inactive publications', () async {
        final active = Publication(name: 'Biblia', code: 'P1', isActive: true);
        final inactive =
            Publication(name: 'Biblia', code: 'P2', isActive: false);

        await dataSource.insert(active);
        await dataSource.insert(inactive);

        final results = await dataSource.findActiveByName('Biblia');
        expect(results.length, 1);
        expect(results.first.isActive, isTrue);
      });

      test('findActiveByName throws ArgumentError on empty name', () async {
        expect(() => dataSource.findActiveByName(''), throwsArgumentError);
        expect(() => dataSource.findActiveByName('   '), throwsArgumentError);
      });
    });
  });
}
