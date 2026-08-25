import 'publication.dart';

abstract interface class PublicationRepository {
  Future<Publication> create(Publication publication);
  Future<List<Publication>> getAll();
  Future<Publication?> getById(int id);
}
