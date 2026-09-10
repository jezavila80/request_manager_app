import '../request.dart';
import '../request_exceptions.dart';
import '../request_repository.dart';

class CreateRequestUseCase {
  final RequestRepository _repository;

  CreateRequestUseCase({required RequestRepository repository})
      : _repository = repository;

  Future<Request> call(Request request) async {
    if (!request.isValidForOrder) {
      throw InvalidRequestForCreationException(
        'La solicitud debe contener al menos un artículo para ser procesada.',
      );
    }

    if (request.id != null) {
      throw RequestAlreadyPersistedException(request.id!);
    }

    for (final item in request.items) {
      if (item.id != null) {
        throw RequestItemAlreadyPersistedException(item.id!);
      }
    }

    return await _repository.create(request);
  }
}
