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
  });
}
