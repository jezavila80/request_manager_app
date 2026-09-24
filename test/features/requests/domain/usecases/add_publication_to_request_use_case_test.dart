import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/core/database/app_database.dart';
import 'package:request_manager_app/core/database/database_constants.dart';
import 'package:request_manager_app/core/time/app_clock.dart';
import 'package:request_manager_app/features/publications/data/publication_local_data_source.dart';
import 'package:request_manager_app/features/publications/domain/publication.dart';
import 'package:request_manager_app/features/requests/data/datasources/request_local_data_source.dart';
import 'package:request_manager_app/features/requests/data/repositories/request_repository_impl.dart';
import 'package:request_manager_app/features/requests/domain/request.dart';
import 'package:request_manager_app/features/requests/domain/request_exceptions.dart';
import 'package:request_manager_app/features/requests/domain/request_item.dart';
import 'package:request_manager_app/features/requests/domain/usecases/add_publication_to_request_use_case.dart';
import 'package:request_manager_app/features/requests/domain/usecases/create_request_use_case.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/time/fixed_clock.dart';
import '../../../../helpers/test_publication_factory.dart';

void main() {
  sqfliteFfiInit();

  group('AddPublicationToRequestUseCase Unit & Application Tests', () {
    late FixedClock clock;
    late AddPublicationToRequestUseCase useCase;

    final t0 = DateTime.utc(2026, 9, 21, 10, 0);
    final t1 = DateTime.utc(2026, 9, 21, 10, 15);
    final t2 = DateTime.utc(2026, 9, 21, 10, 30);

    final pubA = createTestPublication(
      id: 1,
      code: 'PUB-A',
      name: 'Biblia de Estudio',
    );

    final pubB = createTestPublication(
      id: 2,
      code: 'PUB-B',
      name: 'Atalaya',
    );

    final pubC = createTestPublication(
      id: 3,
      code: 'PUB-C',
      name: 'Biblia Letra Grande',
    );

    setUp(() {
      clock = FixedClock(t0);
      useCase = AddPublicationToRequestUseCase(clock: clock);
    });

    // Requirement 1, 2, 3: Crear nuevo Request con AppClock, createdAt == updatedAt, UTC
    test(
        '1-3. createRequest builds Request with AppClock, createdAt == updatedAt, and both are UTC',
        () {
      final request = useCase.createRequest(
        requesterId: 10,
        notes: 'Urgente para reunión',
      );

      expect(request.requesterId, equals(10));
      expect(request.notes, equals('Urgente para reunión'));
      expect(request.items, isEmpty);
      expect(request.createdAt, equals(t0));
      expect(request.updatedAt, equals(t0));
      expect(request.createdAt.isUtc, isTrue);
      expect(request.updatedAt.isUtc, isTrue);
      expect(request.isValidForOrder, isFalse);
    });

    // Requirement 4 & 5: Agregar publicación nueva crea un solo RequestItem con quantityFulfilled == 0
    test(
        '4-5. addPublication creates a single RequestItem with quantityFulfilled == 0 when publication is new',
        () {
      final request = useCase.createRequest(requesterId: 1);

      final result = useCase.addPublication(
        request: request,
        publication: pubA,
        quantity: 2,
      );

      expect(result, isA<PublicationAddedToRequest>());
      final added = result as PublicationAddedToRequest;
      expect(added.publication, equals(pubA));
      expect(added.addedItem.publicationId, equals(pubA.id));
      expect(added.addedItem.quantityRequested, equals(2));
      expect(added.addedItem.quantityFulfilled, equals(0));

      final updatedRequest = added.request;
      expect(updatedRequest.items.length, equals(1));
      expect(updatedRequest.items.first.publicationId, equals(pubA.id));
      expect(updatedRequest.items.first.quantityRequested, equals(2));
      expect(updatedRequest.items.first.quantityFulfilled, equals(0));
      expect(updatedRequest.isValidForOrder, isTrue);
    });

    // Requirement 6: Agregar otra publicación distinta produce dos items
    test(
        '6. addPublication produces two distinct items when adding a second different publication',
        () {
      final request0 = useCase.createRequest(requesterId: 1);

      final result1 = useCase.addPublication(
        request: request0,
        publication: pubA,
        quantity: 2,
      );
      final request1 = (result1 as PublicationAddedToRequest).request;

      final result2 = useCase.addPublication(
        request: request1,
        publication: pubB,
        quantity: 3,
      );
      expect(result2, isA<PublicationAddedToRequest>());
      final request2 = (result2 as PublicationAddedToRequest).request;

      expect(request2.items.length, equals(2));
      expect(request2.items[0].publicationId, equals(pubA.id));
      expect(request2.items[0].quantityRequested, equals(2));
      expect(request2.items[1].publicationId, equals(pubB.id));
      expect(request2.items[1].quantityRequested, equals(3));
      expect(request2.totalQuantityRequested, equals(5));
    });

    // Requirement 7: Detectar publicationId ya existente
    test(
        '7. addPublication detects already existing publicationId and returns PublicationAlreadyInRequest without altering request',
        () {
      final request0 = useCase.createRequest(requesterId: 1);
      final result1 = useCase.addPublication(
        request: request0,
        publication: pubC,
        quantity: 1,
      );
      final request1 = (result1 as PublicationAddedToRequest).request;

      // User attempts to add pubC again with quantity 1
      final result2 = useCase.addPublication(
        request: request1,
        publication: pubC,
        quantity: 1,
      );

      expect(result2, isA<PublicationAlreadyInRequest>());
      final alreadyPresent = result2 as PublicationAlreadyInRequest;
      expect(alreadyPresent.currentRequest, equals(request1));
      expect(alreadyPresent.publication, equals(pubC));
      expect(alreadyPresent.existingItem.publicationId, equals(pubC.id));
      expect(alreadyPresent.existingItem.quantityRequested, equals(1));
      expect(alreadyPresent.quantityToAdd, equals(1));
      expect(alreadyPresent.newTotalQuantity, equals(2));

      // Current request must remain unmodified
      expect(request1.items.length, equals(1));
      expect(request1.items.first.quantityRequested, equals(1));
    });

    // Requirement 8 & 9: Confirmar acumulación mantiene un solo item y calcula 1 + 1 = 2
    test(
        '8-9. confirmAccumulation keeps a single RequestItem and computes 1 + 1 = 2',
        () {
      final request0 = useCase.createRequest(requesterId: 1);
      final result1 = useCase.addPublication(
        request: request0,
        publication: pubC,
        quantity: 1,
      );
      final request1 = (result1 as PublicationAddedToRequest).request;

      // Detects duplicate
      final checkResult = useCase.addPublication(
        request: request1,
        publication: pubC,
        quantity: 1,
      );
      expect(checkResult, isA<PublicationAlreadyInRequest>());

      // User confirms accumulation
      final updatedRequest = useCase.confirmAccumulation(
        request: request1,
        publicationId: pubC.id!,
        quantityToAdd: 1,
      );

      expect(updatedRequest.items.length, equals(1),
          reason: 'Must maintain exactly one RequestItem for that publication');
      expect(updatedRequest.items.first.publicationId, equals(pubC.id));
      expect(updatedRequest.items.first.quantityRequested, equals(2),
          reason: '1 + 1 must equal 2');
      expect(updatedRequest.items.first.quantityFulfilled, equals(0));
    });

    // Requirement 10: Cantidad 2 + 3 = 5
    test('10. confirmAccumulation correctly computes 2 + 3 = 5', () {
      final request0 = useCase.createRequest(requesterId: 1);
      final result1 = useCase.addPublication(
        request: request0,
        publication: pubA,
        quantity: 2,
      );
      final request1 = (result1 as PublicationAddedToRequest).request;

      final updatedRequest = useCase.confirmAccumulation(
        request: request1,
        publicationId: pubA.id!,
        quantityToAdd: 3,
      );

      expect(updatedRequest.items.length, equals(1));
      expect(updatedRequest.items.first.quantityRequested, equals(5),
          reason: '2 + 3 must equal 5');
    });

    // Requirement 11: Acumular no modifica quantityFulfilled
    test(
        '11. confirmAccumulation preserves quantityFulfilled without modifying it',
        () {
      // Create request with pre-existing item that has quantityFulfilled > 0
      final initialItem = RequestItem(
        publicationId: pubA.id!,
        quantityRequested: 4,
        quantityFulfilled: 2,
      );
      final request = Request(
        requesterId: 1,
        items: [initialItem],
        createdAt: t0,
        updatedAt: t0,
      );

      final updated = useCase.confirmAccumulation(
        request: request,
        publicationId: pubA.id!,
        quantityToAdd: 3,
      );

      expect(updated.items.first.quantityRequested, equals(7));
      expect(updated.items.first.quantityFulfilled, equals(2),
          reason: 'quantityFulfilled must remain 2');
    });

    // Requirement 12: Cantidad 0 rechazada
    test(
        '12. Quantity 0 is rejected with ArgumentError in addPublication and confirmAccumulation',
        () {
      final request = useCase.createRequest(requesterId: 1);

      expect(
        () => useCase.addPublication(
          request: request,
          publication: pubA,
          quantity: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => useCase.confirmAccumulation(
          request: request,
          publicationId: pubA.id!,
          quantityToAdd: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    // Requirement 13: Cantidad negativa rechazada
    test(
        '13. Negative quantity is rejected with ArgumentError in addPublication and confirmAccumulation',
        () {
      final request = useCase.createRequest(requesterId: 1);

      expect(
        () => useCase.addPublication(
          request: request,
          publication: pubA,
          quantity: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => useCase.confirmAccumulation(
          request: request,
          publicationId: pubA.id!,
          quantityToAdd: -5,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    // Requirement 14: updatedAt cambia usando el AppClock
    test('14. updatedAt updates using AppClock when adding and accumulating',
        () {
      // 1. Initial creation at t0
      final req0 = useCase.createRequest(requesterId: 1);
      expect(req0.createdAt, equals(t0));
      expect(req0.updatedAt, equals(t0));

      // 2. Advance clock to t1 and add pubA
      useCase = AddPublicationToRequestUseCase(clock: FixedClock(t1));
      final res1 = useCase.addPublication(
        request: req0,
        publication: pubA,
        quantity: 2,
      );
      final req1 = (res1 as PublicationAddedToRequest).request;
      expect(req1.createdAt, equals(t0),
          reason: 'createdAt must remain untouched');
      expect(req1.updatedAt, equals(t1),
          reason: 'updatedAt must update to clock time t1');

      // 3. Advance clock to t2 and accumulate
      useCase = AddPublicationToRequestUseCase(clock: FixedClock(t2));
      final req2 = useCase.confirmAccumulation(
        request: req1,
        publicationId: pubA.id!,
        quantityToAdd: 3,
      );
      expect(req2.createdAt, equals(t0));
      expect(req2.updatedAt, equals(t2),
          reason: 'updatedAt must update to clock time t2');
    });

    // Requirement 17: No se generan dos RequestItem con el mismo publicationId
    test(
        '17. Does not produce two RequestItem with the same publicationId across multiple operations',
        () {
      var req = useCase.createRequest(requesterId: 1);

      // Add pubA
      final resA =
          useCase.addPublication(request: req, publication: pubA, quantity: 2);
      req = (resA as PublicationAddedToRequest).request;

      // Add pubB
      final resB =
          useCase.addPublication(request: req, publication: pubB, quantity: 4);
      req = (resB as PublicationAddedToRequest).request;

      // Add pubC
      final resC =
          useCase.addPublication(request: req, publication: pubC, quantity: 1);
      req = (resC as PublicationAddedToRequest).request;

      expect(req.items.length, equals(3));

      // Try add pubB again -> detected
      final resB2 =
          useCase.addPublication(request: req, publication: pubB, quantity: 2);
      expect(resB2, isA<PublicationAlreadyInRequest>());

      // Confirm accumulation for pubB
      req = useCase.confirmAccumulation(
        request: req,
        publicationId: pubB.id!,
        quantityToAdd: 2,
      );

      // Verify no duplicates
      expect(req.items.length, equals(3));
      final pubBItems = req.items.where((i) => i.publicationId == pubB.id!);
      expect(pubBItems.length, equals(1));
      expect(pubBItems.first.quantityRequested, equals(6));
    });

    test('Rejects publication without positive persisted ID', () {
      final req = useCase.createRequest(requesterId: 1);
      final unpersistedPub = Publication(
        name: 'Sin Persistir',
        createdAt: t0,
        updatedAt: t0,
      );

      expect(
        () => useCase.addPublication(
          request: req,
          publication: unpersistedPub,
          quantity: 1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
        'confirmAccumulation throws RequestItemNotFoundException if publicationId is not in request',
        () {
      final req = useCase.createRequest(requesterId: 1);
      expect(
        () => useCase.confirmAccumulation(
          request: req,
          publicationId: 999,
          quantityToAdd: 2,
        ),
        throwsA(isA<RequestItemNotFoundException>()),
      );
    });

    test(
        'confirmAccumulationForPublication delegates properly and validates publication ID',
        () {
      final req0 = useCase.createRequest(requesterId: 1);
      final res1 =
          useCase.addPublication(request: req0, publication: pubA, quantity: 1);
      final req1 = (res1 as PublicationAddedToRequest).request;

      final updated = useCase.confirmAccumulationForPublication(
        request: req1,
        publication: pubA,
        quantityToAdd: 2,
      );

      expect(updated.items.first.quantityRequested, equals(3));
    });

    test('AddPublicationResult equality and toString representation', () {
      final req = useCase.createRequest(requesterId: 1);
      final item = RequestItem(publicationId: pubA.id!, quantityRequested: 2);

      final added1 = PublicationAddedToRequest(
          request: req, publication: pubA, addedItem: item);
      final added2 = PublicationAddedToRequest(
          request: req, publication: pubA, addedItem: item);
      expect(added1, equals(added2));
      expect(added1.hashCode, equals(added2.hashCode));
      expect(added1.toString(), contains('Biblia de Estudio'));

      final already1 = PublicationAlreadyInRequest(
        currentRequest: req,
        publication: pubA,
        existingItem: item,
        quantityToAdd: 3,
      );
      final already2 = PublicationAlreadyInRequest(
        currentRequest: req,
        publication: pubA,
        existingItem: item,
        quantityToAdd: 3,
      );
      expect(already1, equals(already2));
      expect(already1.hashCode, equals(already2.hashCode));
      expect(already1.toString(), contains('Biblia de Estudio'));
    });
  });

  // Requirements 15 & 16: Integration with CreateRequestUseCase and SQLite transactional persistence
  group(
      'AddPublicationToRequestUseCase & CreateRequestUseCase Integration Tests',
      () {
    late RequestLocalDataSourceImpl localDataSource;
    late RequestRepositoryImpl repository;
    late CreateRequestUseCase createRequestUseCase;
    late PublicationLocalDataSource pubDataSource;
    late AddPublicationToRequestUseCase addPublicationUseCase;

    setUp(() async {
      await AppDatabase.instance.initDatabaseForTesting(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      localDataSource =
          RequestLocalDataSourceImpl(appDatabase: AppDatabase.instance);
      repository = RequestRepositoryImpl(localDataSource: localDataSource);
      createRequestUseCase = CreateRequestUseCase(repository: repository);
      pubDataSource =
          PublicationLocalDataSource(appDatabase: AppDatabase.instance);
      addPublicationUseCase =
          const AddPublicationToRequestUseCase(clock: SystemClock());
    });

    tearDown(() async {
      await AppDatabase.instance.close();
    });

    test(
        '15-16. Full flow: build request in memory with additions & accumulation, then persist via CreateRequestUseCase',
        () async {
      // 1. Insert real publications into SQLite
      final pub1ToInsert =
          createTestPublication(code: 'PUB-1', name: 'Libro A');
      final pub2ToInsert =
          createTestPublication(code: 'PUB-2', name: 'Libro B');
      final p1Id = await pubDataSource.insert(pub1ToInsert);
      final p2Id = await pubDataSource.insert(pub2ToInsert);
      final p1 = pub1ToInsert.copyWith(id: p1Id);
      final p2 = pub2ToInsert.copyWith(id: p2Id);

      // 1b. Insert requester into SQLite
      final db = await AppDatabase.instance.database;
      final reqId = await db.insert(DatabaseConstants.tableRequesters, {
        DatabaseConstants.columnName: 'Comprador Final',
        DatabaseConstants.columnNormalizedName: 'comprador final',
        DatabaseConstants.columnIsActive: 1,
        DatabaseConstants.columnCreatedAt:
            DateTime.now().toUtc().toIso8601String(),
        DatabaseConstants.columnUpdatedAt:
            DateTime.now().toUtc().toIso8601String(),
      });

      // 2. Build new request in memory
      var inMemoryRequest = addPublicationUseCase.createRequest(
        requesterId: reqId,
        notes: 'Pedido validado end-to-end',
      );

      // Empty request cannot be saved
      expect(
        () => createRequestUseCase.call(inMemoryRequest),
        throwsA(isA<InvalidRequestForCreationException>()),
      );

      // Add Publication 1 with quantity 2
      final res1 = addPublicationUseCase.addPublication(
        request: inMemoryRequest,
        publication: p1,
        quantity: 2,
      );
      inMemoryRequest = (res1 as PublicationAddedToRequest).request;

      // Add Publication 2 with quantity 4
      final res2 = addPublicationUseCase.addPublication(
        request: inMemoryRequest,
        publication: p2,
        quantity: 4,
      );
      inMemoryRequest = (res2 as PublicationAddedToRequest).request;

      // Try add Publication 1 again with quantity 3 -> detected
      final res3 = addPublicationUseCase.addPublication(
        request: inMemoryRequest,
        publication: p1,
        quantity: 3,
      );
      expect(res3, isA<PublicationAlreadyInRequest>());
      final alreadyIn = res3 as PublicationAlreadyInRequest;
      expect(alreadyIn.existingItem.quantityRequested, equals(2));
      expect(alreadyIn.quantityToAdd, equals(3));
      expect(alreadyIn.newTotalQuantity, equals(5));

      // User confirms accumulation (2 + 3 = 5)
      inMemoryRequest = addPublicationUseCase.confirmAccumulation(
        request: inMemoryRequest,
        publicationId: p1.id!,
        quantityToAdd: 3,
      );

      expect(inMemoryRequest.items.length, equals(2));
      expect(inMemoryRequest.items[0].publicationId, equals(p1.id));
      expect(inMemoryRequest.items[0].quantityRequested, equals(5));
      expect(inMemoryRequest.items[1].publicationId, equals(p2.id));
      expect(inMemoryRequest.items[1].quantityRequested, equals(4));

      // 3. Persist the complete aggregate via CreateRequestUseCase
      final persisted = await createRequestUseCase.call(inMemoryRequest);

      // 4. Verify IDs assigned and persisted state in SQLite
      expect(persisted.id, isNotNull);
      expect(persisted.id, greaterThan(0));
      expect(persisted.requesterId, equals(reqId));
      expect(persisted.items.length, equals(2));
      expect(persisted.items[0].id, isNotNull);
      expect(persisted.items[0].publicationId, equals(p1.id));
      expect(persisted.items[0].quantityRequested, equals(5));
      expect(persisted.items[0].quantityFulfilled, equals(0));
      expect(persisted.items[1].id, isNotNull);
      expect(persisted.items[1].publicationId, equals(p2.id));
      expect(persisted.items[1].quantityRequested, equals(4));
      expect(persisted.items[1].quantityFulfilled, equals(0));

      // Query database directly to confirm SQLite rows
      final retrieved = await localDataSource.getById(persisted.id!);
      expect(retrieved, isNotNull);
      expect(retrieved!.items.length, equals(2));
      expect(retrieved.items[0].quantityRequested, equals(5));
      expect(retrieved.items[1].quantityRequested, equals(4));
      expect(retrieved.totalQuantityRequested, equals(9));
      expect(retrieved.createdAt.isUtc, isTrue);
      expect(retrieved.updatedAt.isUtc, isTrue);
    });
  });
}
