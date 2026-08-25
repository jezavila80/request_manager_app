import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_constants.dart';
import '../domain/publication.dart';
import '../domain/publication_exceptions.dart';
import 'publication_mapper.dart';

class PublicationLocalDataSource {
  final AppDatabase _appDatabase;

  PublicationLocalDataSource({AppDatabase? appDatabase})
      : _appDatabase = appDatabase ?? AppDatabase.instance;

  Future<int> insert(Publication publication) async {
    try {
      final db = await _appDatabase.database;
      final map = PublicationMapper.toMap(publication);
      final id = await db.insert(
        DatabaseConstants.tablePublications,
        map,
      );
      if (id <= 0) {
        throw PublicationPersistenceException(
          'La base de datos devolvió un ID de inserción inválido ($id).',
        );
      }
      return id;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError() ||
          e.toString().toLowerCase().contains('unique constraint failed')) {
        throw DuplicatePublicationCodeException(publication.code ?? '', e);
      }
      throw PublicationPersistenceException(
        'Error de persistencia en SQLite al insertar la publicación.',
        e,
      );
    } catch (e) {
      if (e is PublicationException) {
        rethrow;
      }
      throw PublicationPersistenceException(
        'Error inesperado al insertar la publicación en la base de datos.',
        e,
      );
    }
  }
}
