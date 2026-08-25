import 'publication.dart';

abstract interface class PublicationRepository {
  Future<Publication> create(Publication publication);
}
