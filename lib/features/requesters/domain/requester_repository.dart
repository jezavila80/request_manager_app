import 'requester.dart';

abstract interface class RequesterRepository {
  Future<Requester> create(Requester requester);
  Future<Requester?> getById(int id);
  Future<Requester?> findByNormalizedName(String normalizedName);
  Future<List<Requester>> searchActiveByName(String query, {int limit = 20});
  Future<List<Requester>> getAll();
}
