import 'publication.dart';

abstract interface class PublicationRepository {
  Future<Publication> create(Publication publication);
  Future<List<Publication>> getAll();
  Future<List<Publication>> getActivePublications();
  Future<Publication?> getById(int id);
  Future<List<Publication>> searchByName(String query, {int limit = 20});
  Future<List<Publication>> searchByCode(String query, {int limit = 20});
  Future<Publication?> findByExactCode(String code);
  Future<List<Publication>> findActiveByName(String name);
}
