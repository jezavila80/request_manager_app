import '../../domain/request.dart';
import '../../domain/request_exceptions.dart';
import '../../domain/request_repository.dart';
import '../datasources/request_local_data_source.dart';

class RequestRepositoryImpl implements RequestRepository {
  final RequestLocalDataSource _localDataSource;

  RequestRepositoryImpl({RequestLocalDataSource? localDataSource})
      : _localDataSource = localDataSource ?? RequestLocalDataSourceImpl();

  @override
  Future<Request> create(Request request) async {
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

    return await _localDataSource.create(request);
  }
}
