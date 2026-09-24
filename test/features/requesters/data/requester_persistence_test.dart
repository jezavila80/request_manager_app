import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/core/database/app_database.dart';
import 'package:request_manager_app/core/database/database_constants.dart';
import 'package:request_manager_app/features/requesters/data/datasources/requester_local_data_source.dart';
import 'package:request_manager_app/features/requesters/data/repositories/requester_repository_impl.dart';
import 'package:request_manager_app/features/requesters/domain/requester.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('Requester SQLite Persistence & Repository Tests', () {
    late RequesterLocalDataSource localDataSource;
    late RequesterRepositoryImpl repository;

    final t0 = DateTime.utc(2026, 9, 22, 10, 0);

    setUp(() async {
      await AppDatabase.instance.initDatabaseForTesting(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      localDataSource = RequesterLocalDataSourceImpl();
      repository = RequesterRepositoryImpl(localDataSource: localDataSource);
    });

    tearDown(() async {
      await AppDatabase.instance.close();
    });

    test('create generates ID and preserves UTC timestamps', () async {
      final requester = Requester(
        name: 'María Soto',
        createdAt: t0,
        updatedAt: t0,
      );

      final created = await repository.create(requester);

      expect(created.id, isNotNull);
      expect(created.id!, greaterThan(0));
      expect(created.name, equals('María Soto'));
      expect(created.normalizedName, equals('maria soto'));
      expect(created.createdAt, equals(t0));
      expect(created.updatedAt, equals(t0));
      expect(created.createdAt.isUtc, isTrue);
      expect(created.updatedAt.isUtc, isTrue);

      final fetched = await repository.getById(created.id!);
      expect(fetched, isNotNull);
      expect(fetched!.name, equals('María Soto'));
      expect(fetched.normalizedName, equals('maria soto'));
    });

    test('findByNormalizedName retrieves exact record', () async {
      await repository.create(Requester(
        name: 'José Pérez',
        createdAt: t0,
        updatedAt: t0,
      ));

      final found = await repository.findByNormalizedName('jose perez');
      expect(found, isNotNull);
      expect(found!.name, equals('José Pérez'));

      final notFound = await repository.findByNormalizedName('inexistente');
      expect(notFound, isNull);
    });

    test(
        'Uniqueness of normalized_name blocks duplicates regardless of accents/case/spaces',
        () async {
      await repository.create(Requester(
        name: 'María Soto',
        createdAt: t0,
        updatedAt: t0,
      ));

      // Attempting to insert duplicate via datasource throws DatabaseException
      expect(
        () => localDataSource.create(Requester(
          name: 'Maria Soto',
          createdAt: t0,
          updatedAt: t0,
        )),
        throwsA(isA<DatabaseException>()),
      );

      expect(
        () => localDataSource.create(Requester(
          name: 'MARIA SOTO',
          createdAt: t0,
          updatedAt: t0,
        )),
        throwsA(isA<DatabaseException>()),
      );

      expect(
        () => localDataSource.create(Requester(
          name: '  María   Soto ',
          createdAt: t0,
          updatedAt: t0,
        )),
        throwsA(isA<DatabaseException>()),
      );
    });

    test(
        'searchActiveByName returns only active requesters matching accent-insensitively',
        () async {
      await repository.create(Requester(
        name: 'María Soto',
        isActive: true,
        createdAt: t0,
        updatedAt: t0,
      ));

      await repository.create(Requester(
        name: 'Mario Solís',
        isActive: true,
        createdAt: t0,
        updatedAt: t0,
      ));

      // Inactive requester with matching name
      final dbRef = await AppDatabase.instance.database;
      await dbRef.insert(DatabaseConstants.tableRequesters, {
        DatabaseConstants.columnName: 'Mariano Soto',
        DatabaseConstants.columnNormalizedName: 'mariano soto',
        DatabaseConstants.columnIsActive: 0,
        DatabaseConstants.columnCreatedAt: t0.toIso8601String(),
        DatabaseConstants.columnUpdatedAt: t0.toIso8601String(),
      });

      // Searching with "maria" (without accent) finds "María Soto"
      final results1 = await repository.searchActiveByName('maria');
      expect(results1.length, equals(1));
      expect(results1.first.name, equals('María Soto'));

      // Searching with "so" finds active ones only
      final results2 = await repository.searchActiveByName('so');
      expect(results2.length, equals(2));
      expect(results2.any((r) => r.name == 'Mariano Soto'), isFalse);
    });
  });
}
