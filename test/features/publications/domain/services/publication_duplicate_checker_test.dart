import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:request_manager_app/core/database/app_database.dart';
import 'package:request_manager_app/features/publications/data/publication_repository_impl.dart';
import 'package:request_manager_app/features/publications/domain/duplicate_check_result.dart';
import 'package:request_manager_app/features/publications/domain/publication.dart';
import 'package:request_manager_app/features/publications/domain/publication_exceptions.dart';
import 'package:request_manager_app/features/publications/domain/services/publication_duplicate_checker.dart';
import 'package:request_manager_app/features/publications/domain/tri_state_value.dart';

void main() {
  sqfliteFfiInit();

  group('PublicationDuplicateChecker Tests', () {
    late PublicationRepositoryImpl repository;
    late PublicationDuplicateChecker checker;

    setUp(() async {
      await AppDatabase.instance.initDatabaseForTesting(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      repository = PublicationRepositoryImpl();
      checker = PublicationDuplicateChecker(repository);
    });

    tearDown(() async {
      await AppDatabase.instance.close();
    });

    test(
        '30. DuplicateCheckResult represents status and matches list correctly',
        () {
      final pub = Publication(name: 'Test Pub');
      final result = DuplicateCheckResult(
        status: DuplicateCheckStatus.possibleDuplicate,
        matches: [pub],
      );

      expect(result.status, DuplicateCheckStatus.possibleDuplicate);
      expect(result.matches, [pub]);
      expect(result.toString(), contains('possibleDuplicate'));
    });

    test('31. Test - código exacto duplicado', () async {
      final existing =
          Publication(name: 'Existente', code: 'RBI-8', isActive: true);
      await repository.create(existing);

      final candidate = Publication(name: 'Candidato Nuevo', code: 'RBI-8');
      final result = await checker.checkDuplicates(candidate);

      expect(result.status, DuplicateCheckStatus.duplicateCode);
      expect(result.matches.length, 1);
      expect(result.matches.first.name, 'Existente');
    });

    test('32. Test - código duplicado case-insensitive', () async {
      final existing =
          Publication(name: 'Existente', code: 'RBI-8', isActive: true);
      await repository.create(existing);

      final candidate = Publication(name: 'Candidato Nuevo', code: 'rbi-8');
      final result = await checker.checkDuplicates(candidate);

      expect(result.status, DuplicateCheckStatus.duplicateCode);
      expect(result.matches.length, 1);
      expect(result.matches.first.name, 'Existente');
    });

    test('33. Test - código parecido pero diferente', () async {
      final existing =
          Publication(name: 'Existente', code: 'RBI-8', isActive: true);
      await repository.create(existing);

      final candidate = Publication(name: 'Candidato Nuevo', code: 'RBI-80');
      final result = await checker.checkDuplicates(candidate);

      // Should not match duplicateCode, nor possibleDuplicate (different name)
      expect(result.status, DuplicateCheckStatus.none);
      expect(result.matches, isEmpty);
    });

    test('34. Test - mismo nombre y atributos (casing/espacios)', () async {
      final existing = Publication(
        name: 'Biblia Letra Grande',
        type: 'Libro',
        size: TriStateValue.conValor('Grande'),
        version: TriStateValue.conValor('Reina Valera'),
        isActive: true,
      );
      await repository.create(existing);

      final candidate = Publication(
        name: ' biblia letra grande ',
        type: ' libro ',
        size: TriStateValue.conValor(' grande '),
        version: TriStateValue.conValor(' reina valera '),
      );
      final result = await checker.checkDuplicates(candidate);

      expect(result.status, DuplicateCheckStatus.possibleDuplicate);
      expect(result.matches.length, 1);
      expect(result.matches.first.name, 'Biblia Letra Grande');
    });

    test('35. Test - mismo nombre, tamaño diferente', () async {
      final existing = Publication(
        name: 'Biblia',
        type: 'Libro',
        size: TriStateValue.conValor('Grande'),
        version: TriStateValue.conValor('Reina Valera'),
        isActive: true,
      );
      await repository.create(existing);

      final candidate = Publication(
        name: 'Biblia',
        type: 'Libro',
        size: TriStateValue.conValor('Bolsillo'),
        version: TriStateValue.conValor('Reina Valera'),
      );
      final result = await checker.checkDuplicates(candidate);

      expect(result.status, DuplicateCheckStatus.none);
      expect(result.matches, isEmpty);
    });

    test('36. Test - mismo nombre, versión diferente', () async {
      final existing = Publication(
        name: 'Biblia',
        type: 'Libro',
        size: TriStateValue.conValor('Grande'),
        version: TriStateValue.conValor('Reina Valera'),
        isActive: true,
      );
      await repository.create(existing);

      final candidate = Publication(
        name: 'Biblia',
        type: 'Libro',
        size: TriStateValue.conValor('Grande'),
        version: TriStateValue.conValor('King James'),
      );
      final result = await checker.checkDuplicates(candidate);

      expect(result.status, DuplicateCheckStatus.none);
      expect(result.matches, isEmpty);
    });

    test('37. Test - NOT_APPLICABLE', () async {
      final existing = Publication(
        name: 'Biblia',
        type: 'Libro',
        size: const TriStateValue.noAplica(),
        version: const TriStateValue.noAplica(),
        isActive: true,
      );
      await repository.create(existing);

      final candidate = Publication(
        name: 'Biblia',
        type: 'Libro',
        size: const TriStateValue.noAplica(),
        version: const TriStateValue.noAplica(),
      );
      final result = await checker.checkDuplicates(candidate);

      expect(result.status, DuplicateCheckStatus.possibleDuplicate);
      expect(result.matches.length, 1);
    });

    test(
        '38. Test - UNDEFINED vs NOT_APPLICABLE (non-identical but compatible)',
        () async {
      // 1. Existing has undefined, candidate has not_applicable
      final existing1 = Publication(
        name: 'Biblia Undef',
        size: const TriStateValue.sinDefinir(),
        isActive: true,
      );
      await repository.create(existing1);

      final candidate1 = Publication(
        name: 'Biblia Undef',
        size: const TriStateValue.noAplica(),
      );
      final result1 = await checker.checkDuplicates(candidate1);
      expect(result1.status, DuplicateCheckStatus.possibleDuplicate);

      // 2. Existing has not_applicable, candidate has undefined
      final existing2 = Publication(
        name: 'Biblia NotApp',
        size: const TriStateValue.noAplica(),
        isActive: true,
      );
      await repository.create(existing2);

      final candidate2 = Publication(
        name: 'Biblia NotApp',
        size: const TriStateValue.sinDefinir(),
      );
      final result2 = await checker.checkDuplicates(candidate2);
      expect(result2.status, DuplicateCheckStatus.possibleDuplicate);
    });

    test('39. Test - Drafts idénticos', () async {
      final existingDraft = Publication(
        code: null,
        name: 'Biblia por identificar',
        type: null,
        size: const TriStateValue.sinDefinir(),
        version: const TriStateValue.sinDefinir(),
        isActive: true,
      );
      await repository.create(existingDraft);

      final candidateDraft = Publication(
        code: null,
        name: 'Biblia por identificar',
        type: null,
        size: const TriStateValue.sinDefinir(),
        version: const TriStateValue.sinDefinir(),
      );
      final result = await checker.checkDuplicates(candidateDraft);

      expect(result.status, DuplicateCheckStatus.possibleDuplicate);
      expect(result.matches.length, 1);
      expect(result.matches.first.name, 'Biblia por identificar');
    });

    test('40. Test - Draft compatible con registro más completo', () async {
      final existingIncomplete = Publication(
        name: 'Biblia',
        type: 'Libro',
        size: TriStateValue.conValor('Grande'),
        version: const TriStateValue.sinDefinir(),
        isActive: true,
      );
      await repository.create(existingIncomplete);

      final candidateComplete = Publication(
        name: 'Biblia',
        type: 'Libro',
        size: TriStateValue.conValor('Grande'),
        version: TriStateValue.conValor('Reina Valera'),
      );
      final result = await checker.checkDuplicates(candidateComplete);

      expect(result.status, DuplicateCheckStatus.possibleDuplicate);
      expect(result.matches.length, 1);
    });

    test('41. Test - contradicción explícita', () async {
      final existing = Publication(
        name: 'Biblia',
        type: 'Libro',
        size: TriStateValue.conValor('Grande'),
        version: TriStateValue.conValor('Reina Valera'),
        isActive: true,
      );
      await repository.create(existing);

      final candidate = Publication(
        name: 'Biblia',
        type: 'Revista', // different type -> contradiction
        size: TriStateValue.conValor('Grande'),
        version: TriStateValue.conValor('Reina Valera'),
      );
      final result = await checker.checkDuplicates(candidate);

      expect(result.status, DuplicateCheckStatus.none);
      expect(result.matches, isEmpty);
    });

    test(
        '42. Test - inactivo: código duplicado bloquea, atributos similares se ignoran',
        () async {
      // Test code duplicate with inactive record
      final inactive1 =
          Publication(name: 'Inactivo 1', code: 'RBI-8', isActive: false);
      await repository.create(inactive1);

      final candidate1 = Publication(name: 'Candidato', code: 'RBI-8');
      final result1 = await checker.checkDuplicates(candidate1);
      expect(result1.status, DuplicateCheckStatus.duplicateCode);
      expect(result1.matches.length, 1);
      expect(result1.matches.first.name, 'Inactivo 1');

      // Test code duplicate with inactive record and different casing (rbi-8 vs RBI-8)
      final candidateCase = Publication(name: 'Candidato Case', code: 'rbi-8');
      final resultCase = await checker.checkDuplicates(candidateCase);
      expect(resultCase.status, DuplicateCheckStatus.duplicateCode);

      // Test attribute duplicate with inactive record (must return none, not possibleDuplicate)
      final inactive2 = Publication(
        name: 'Biblia Letra Grande',
        type: 'Libro',
        size: TriStateValue.conValor('Grande'),
        version: TriStateValue.conValor('Reina Valera'),
        isActive: false,
      );
      await repository.create(inactive2);

      final candidate2 = Publication(
        name: 'Biblia Letra Grande',
        type: 'Libro',
        size: TriStateValue.conValor('Grande'),
        version: TriStateValue.conValor('Reina Valera'),
      );
      final result2 = await checker.checkDuplicates(candidate2);
      expect(result2.status, DuplicateCheckStatus.none);
    });

    test('43. Test - múltiples coincidencias', () async {
      final existing1 = Publication(
        name: 'Biblia Duplicada',
        type: 'Libro',
        size: TriStateValue.conValor('Grande'),
        version: const TriStateValue.sinDefinir(),
        isActive: true,
      );
      final existing2 = Publication(
        name: 'Biblia Duplicada',
        type: 'Libro',
        size: const TriStateValue.sinDefinir(),
        version: TriStateValue.conValor('Reina Valera'),
        isActive: true,
      );
      await repository.create(existing1);
      await repository.create(existing2);

      final candidate = Publication(
        name: 'Biblia Duplicada',
        type: 'Libro',
        size: TriStateValue.conValor('Grande'),
        version: TriStateValue.conValor('Reina Valera'),
      );
      final result = await checker.checkDuplicates(candidate);

      expect(result.status, DuplicateCheckStatus.possibleDuplicate);
      expect(result.matches.length, 2);
    });

    test(
        '44. Regresión CREATE: checker previene insert si existe código inactivo',
        () async {
      final inactivePub = Publication(
        name: 'Biblia Antigua Inactiva',
        code: 'RBI-8',
        isActive: false,
      );
      await repository.create(inactivePub);

      final newCandidate = Publication(
        name: 'Nueva Biblia RBI-8',
        code: 'RBI-8',
        isActive: true,
      );

      final checkResult = await checker.checkDuplicates(newCandidate);
      expect(checkResult.status, DuplicateCheckStatus.duplicateCode);
      expect(checkResult.matches.length, 1);
      expect(checkResult.matches.first.code, 'RBI-8');

      expect(
        () => repository.create(newCandidate),
        throwsA(isA<DuplicatePublicationCodeException>()),
      );
    });
  });
}
