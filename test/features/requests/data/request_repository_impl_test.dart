import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/features/requests/data/datasources/request_local_data_source.dart';
import 'package:request_manager_app/features/requests/data/repositories/request_repository_impl.dart';
import 'package:request_manager_app/features/requests/domain/request.dart';
import 'package:request_manager_app/features/requests/domain/request_exceptions.dart';
import 'package:request_manager_app/features/requests/domain/request_item.dart';

class FakeRequestLocalDataSource implements RequestLocalDataSource {
  Request? passedRequest;
  Request? responseToReturn;
  List<Request> allRequestsToReturn = [];
  Request? getByIdToReturn;
  int? passedGetByIdId;
  bool getAllCalled = false;

  @override
  Future<Request> create(Request request) async {
    passedRequest = request;
    if (responseToReturn != null) {
      return responseToReturn!;
    }
    return request.copyWith(
      id: 10,
      items: request.items.map((i) => i.copyWith(id: 100)).toList(),
    );
  }

  @override
  Future<List<Request>> getAll() async {
    getAllCalled = true;
    return allRequestsToReturn;
  }

  @override
  Future<Request?> getById(int id) async {
    passedGetByIdId = id;
    return getByIdToReturn;
  }
}

void main() {
  group('RequestRepositoryImpl Unit Tests', () {
    late FakeRequestLocalDataSource fakeDataSource;
    late RequestRepositoryImpl repository;

    setUp(() {
      fakeDataSource = FakeRequestLocalDataSource();
      repository = RequestRepositoryImpl(localDataSource: fakeDataSource);
    });

    test('create delegates valid Request to RequestLocalDataSource', () async {
      final request = Request(
        requestedBy: 'Juan',
        items: [RequestItem(publicationId: 1, quantityRequested: 2)],
      );

      final result = await repository.create(request);

      expect(fakeDataSource.passedRequest, equals(request));
      expect(result.id, equals(10));
      expect(result.items.first.id, equals(100));
    });

    test('create rejects Request without items (isValidForOrder == false)',
        () async {
      final invalidRequest = Request(
        requestedBy: 'Juan',
        items: const [],
      );

      expect(
        () => repository.create(invalidRequest),
        throwsA(isA<InvalidRequestForCreationException>()),
      );
      expect(fakeDataSource.passedRequest, isNull);
    });

    test('create rejects Request with pre-existing id', () async {
      final invalidRequest = Request(
        id: 5,
        requestedBy: 'Juan',
        items: [RequestItem(publicationId: 1, quantityRequested: 2)],
      );

      expect(
        () => repository.create(invalidRequest),
        throwsA(isA<RequestAlreadyPersistedException>()),
      );
      expect(fakeDataSource.passedRequest, isNull);
    });

    test('create rejects RequestItem with pre-existing id', () async {
      final invalidRequest = Request(
        requestedBy: 'Juan',
        items: [RequestItem(id: 50, publicationId: 1, quantityRequested: 2)],
      );

      expect(
        () => repository.create(invalidRequest),
        throwsA(isA<RequestItemAlreadyPersistedException>()),
      );
      expect(fakeDataSource.passedRequest, isNull);
    });

    test('getAll delegates to RequestLocalDataSource and returns list',
        () async {
      final sampleRequests = [
        Request(
          id: 1,
          requestedBy: 'Carlos',
          items: [RequestItem(id: 1, publicationId: 10, quantityRequested: 1)],
        ),
      ];
      fakeDataSource.allRequestsToReturn = sampleRequests;

      final result = await repository.getAll();

      expect(fakeDataSource.getAllCalled, isTrue);
      expect(result, equals(sampleRequests));
    });

    test('getById delegates valid id to RequestLocalDataSource', () async {
      final sampleRequest = Request(
        id: 7,
        requestedBy: 'Elena',
        items: [RequestItem(id: 2, publicationId: 10, quantityRequested: 3)],
      );
      fakeDataSource.getByIdToReturn = sampleRequest;

      final result = await repository.getById(7);

      expect(fakeDataSource.passedGetByIdId, equals(7));
      expect(result, equals(sampleRequest));
    });

    test('getById returns null when request is not found', () async {
      fakeDataSource.getByIdToReturn = null;

      final result = await repository.getById(99);

      expect(fakeDataSource.passedGetByIdId, equals(99));
      expect(result, isNull);
    });

    test('getById throws ArgumentError when id <= 0', () async {
      expect(
        () => repository.getById(0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repository.getById(-1),
        throwsA(isA<ArgumentError>()),
      );
      expect(fakeDataSource.passedGetByIdId, isNull);
    });
  });
}
