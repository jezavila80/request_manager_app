import 'request.dart';

abstract interface class RequestRepository {
  Future<Request> create(Request request);
}
