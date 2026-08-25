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

  Future<List<Publication>> getAll() async {
    try {
      final db = await _appDatabase.database;
      final maps = await db.query(
        DatabaseConstants.tablePublications,
        orderBy:
            '${DatabaseConstants.columnName} COLLATE NOCASE ASC, ${DatabaseConstants.columnId} ASC',
      );
      return maps.map((map) => PublicationMapper.fromMap(map)).toList();
    } on DatabaseException catch (e) {
      throw PublicationPersistenceException(
        'Error de persistencia en SQLite al consultar las publicaciones.',
        e,
      );
    } catch (e) {
      throw PublicationPersistenceException(
        'Error inesperado al consultar las publicaciones en la base de datos.',
        e,
      );
    }
  }

  Future<Publication?> getById(int id) async {
    if (id <= 0) {
      throw ArgumentError('El ID de la publicación debe ser mayor a 0.');
    }
    try {
      final db = await _appDatabase.database;
      final maps = await db.query(
        DatabaseConstants.tablePublications,
        where: '${DatabaseConstants.columnId} = ?',
        whereArgs: [id],
      );
      if (maps.isEmpty) {
        return null;
      }
      return PublicationMapper.fromMap(maps.first);
    } on DatabaseException catch (e) {
      throw PublicationPersistenceException(
        'Error de persistencia en SQLite al consultar la publicación con ID: $id.',
        e,
      );
    } catch (e) {
      if (e is ArgumentError) rethrow;
      throw PublicationPersistenceException(
        'Error inesperado al consultar la publicación con ID: $id en la base de datos.',
        e,
      );
    }
  }
}
