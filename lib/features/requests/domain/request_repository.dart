import 'request.dart';

abstract interface class RequestRepository {
  Future<Request> create(Request request);

  Future<List<Request>> getAll();

  Future<Request?> getById(int id);
}
