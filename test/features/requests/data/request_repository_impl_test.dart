import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/features/requests/data/datasources/request_local_data_source.dart';
import 'package:request_manager_app/features/requests/data/repositories/request_repository_impl.dart';
import 'package:request_manager_app/features/requests/domain/request.dart';
import 'package:request_manager_app/features/requests/domain/request_exceptions.dart';
import 'package:request_manager_app/features/requests/domain/request_item.dart';

class FakeRequestLocalDataSource implements RequestLocalDataSource {
  Request? passedRequest;
  Request? responseToReturn;

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
  });
}
