import 'request.dart';
import 'request_list_item.dart';

abstract interface class RequestRepository {
  Future<Request> create(Request request);

  Future<List<Request>> getAll();

  Future<Request?> getById(int id);

  /// Returns a lightweight summary projection of all requests for listing.
  Future<List<RequestListItem>> getRequestList();
}
