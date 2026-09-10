import 'package:flutter_test/flutter_test.dart';
import 'package:request_manager_app/features/requests/domain/request.dart';
import 'package:request_manager_app/features/requests/domain/request_exceptions.dart';
import 'package:request_manager_app/features/requests/domain/request_item.dart';
import 'package:request_manager_app/features/requests/domain/request_repository.dart';
import 'package:request_manager_app/features/requests/domain/usecases/create_request_use_case.dart';

class FakeRequestRepository implements RequestRepository {
  Request? passedRequest;

  @override
  Future<Request> create(Request request) async {
    passedRequest = request;
    return request.copyWith(
      id: 88,
      items: request.items.map((i) => i.copyWith(id: 808)).toList(),
    );
  }
}

void main() {
  group('CreateRequestUseCase Unit Tests', () {
    late FakeRequestRepository fakeRepository;
    late CreateRequestUseCase useCase;

    setUp(() {
      fakeRepository = FakeRequestRepository();
      useCase = CreateRequestUseCase(repository: fakeRepository);
    });

    test(
        'call delegates valid Request to repository and returns persisted Request',
        () async {
      final request = Request(
        requestedBy: 'María',
        items: [RequestItem(publicationId: 2, quantityRequested: 1)],
      );

      final result = await useCase.call(request);

      expect(fakeRepository.passedRequest, equals(request));
      expect(result.id, equals(88));
      expect(result.items.first.id, equals(808));
    });

    test(
        'call throws InvalidRequestForCreationException when request.isValidForOrder is false',
        () async {
      final invalidRequest = Request(
        requestedBy: 'María',
        items: const [],
      );

      expect(
        () => useCase.call(invalidRequest),
        throwsA(isA<InvalidRequestForCreationException>()),
      );
      expect(fakeRepository.passedRequest, isNull);
    });

    test(
        'call throws RequestAlreadyPersistedException when request.id is not null',
        () async {
      final invalidRequest = Request(
        id: 12,
        requestedBy: 'María',
        items: [RequestItem(publicationId: 2, quantityRequested: 1)],
      );

      expect(
        () => useCase.call(invalidRequest),
        throwsA(isA<RequestAlreadyPersistedException>()),
      );
      expect(fakeRepository.passedRequest, isNull);
    });

    test(
        'call throws RequestItemAlreadyPersistedException when any item.id is not null',
        () async {
      final invalidRequest = Request(
        requestedBy: 'María',
        items: [RequestItem(id: 44, publicationId: 2, quantityRequested: 1)],
      );

      expect(
        () => useCase.call(invalidRequest),
        throwsA(isA<RequestItemAlreadyPersistedException>()),
      );
      expect(fakeRepository.passedRequest, isNull);
    });
  });
}
