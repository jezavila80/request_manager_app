import '../domain/publication.dart';
import '../domain/publication_exceptions.dart';
import '../domain/publication_repository.dart';
import 'publication_local_data_source.dart';

class PublicationRepositoryImpl implements PublicationRepository {
  final PublicationLocalDataSource _localDataSource;

  PublicationRepositoryImpl({PublicationLocalDataSource? localDataSource})
      : _localDataSource = localDataSource ?? PublicationLocalDataSource();

  @override
  Future<Publication> create(Publication publication) async {
    if (publication.id != null) {
      throw PublicationAlreadyPersistedException(publication.id!);
    }

    final generatedId = await _localDataSource.insert(publication);

    return publication.copyWith(id: generatedId);
  }
}
