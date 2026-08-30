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

  Future<List<Publication>> searchByName(String query, {int limit = 20}) async {
    if (limit <= 0) {
      throw ArgumentError('El límite de búsqueda debe ser mayor a 0.');
    }
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return [];
    }

    try {
      final db = await _appDatabase.database;
      final escaped = _escapeLike(trimmedQuery);

      final maps = await db.rawQuery(
        'SELECT * FROM ${DatabaseConstants.tablePublications} '
        'WHERE ${DatabaseConstants.columnIsActive} = 1 '
        'AND ${DatabaseConstants.columnName} LIKE ? ESCAPE \'\\\' '
        'ORDER BY '
        '  CASE '
        '    WHEN ${DatabaseConstants.columnName} = ? COLLATE NOCASE THEN 0 '
        '    WHEN ${DatabaseConstants.columnName} LIKE ? ESCAPE \'\\\' THEN 1 '
        '    ELSE 2 '
        '  END, '
        '  ${DatabaseConstants.columnName} COLLATE NOCASE ASC, '
        '  ${DatabaseConstants.columnId} ASC '
        'LIMIT ?',
        ['%$escaped%', trimmedQuery, '$escaped%', limit],
      );

      return maps.map((map) => PublicationMapper.fromMap(map)).toList();
    } on DatabaseException catch (e) {
      throw PublicationPersistenceException(
        'Error de persistencia en SQLite al buscar publicaciones por nombre.',
        e,
      );
    } catch (e) {
      if (e is ArgumentError) rethrow;
      throw PublicationPersistenceException(
        'Error inesperado al buscar publicaciones por nombre en la base de datos.',
        e,
      );
    }
  }

  Future<List<Publication>> searchByCode(String query, {int limit = 20}) async {
    if (limit <= 0) {
      throw ArgumentError('El límite de búsqueda debe ser mayor a 0.');
    }
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return [];
    }

    try {
      final db = await _appDatabase.database;
      final escaped = _escapeLike(trimmedQuery);

      final maps = await db.rawQuery(
        'SELECT * FROM ${DatabaseConstants.tablePublications} '
        'WHERE ${DatabaseConstants.columnIsActive} = 1 '
        'AND ${DatabaseConstants.columnCode} IS NOT NULL '
        'AND ${DatabaseConstants.columnCode} LIKE ? ESCAPE \'\\\' '
        'ORDER BY '
        '  CASE '
        '    WHEN ${DatabaseConstants.columnCode} = ? COLLATE NOCASE THEN 0 '
        '    WHEN ${DatabaseConstants.columnCode} LIKE ? ESCAPE \'\\\' THEN 1 '
        '    ELSE 2 '
        '  END, '
        '  ${DatabaseConstants.columnCode} COLLATE NOCASE ASC, '
        '  ${DatabaseConstants.columnId} ASC '
        'LIMIT ?',
        ['%$escaped%', trimmedQuery, '$escaped%', limit],
      );

      return maps.map((map) => PublicationMapper.fromMap(map)).toList();
    } on DatabaseException catch (e) {
      throw PublicationPersistenceException(
        'Error de persistencia en SQLite al buscar publicaciones por código.',
        e,
      );
    } catch (e) {
      if (e is ArgumentError) rethrow;
      throw PublicationPersistenceException(
        'Error inesperado al buscar publicaciones por código en la base de datos.',
        e,
      );
    }
  }

  Future<Publication?> findActiveByExactCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError(
          'El código no puede estar vacío o contener únicamente espacios.');
    }
    try {
      final db = await _appDatabase.database;
      final maps = await db.query(
        DatabaseConstants.tablePublications,
        where:
            '${DatabaseConstants.columnIsActive} = 1 AND ${DatabaseConstants.columnCode} = ? COLLATE NOCASE',
        whereArgs: [trimmed],
      );
      if (maps.isEmpty) {
        return null;
      }
      return PublicationMapper.fromMap(maps.first);
    } on DatabaseException catch (e) {
      throw PublicationPersistenceException(
        'Error de persistencia en SQLite al buscar publicación activa por código exacto.',
        e,
      );
    } catch (e) {
      if (e is ArgumentError) rethrow;
      throw PublicationPersistenceException(
        'Error inesperado al buscar publicación activa por código exacto en la base de datos.',
        e,
      );
    }
  }

  Future<List<Publication>> findActiveByName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError(
          'El nombre no puede estar vacío o contener únicamente espacios.');
    }
    try {
      final db = await _appDatabase.database;
      final maps = await db.query(
        DatabaseConstants.tablePublications,
        where:
            '${DatabaseConstants.columnIsActive} = 1 AND ${DatabaseConstants.columnName} = ? COLLATE NOCASE',
        whereArgs: [trimmed],
        orderBy:
            '${DatabaseConstants.columnName} COLLATE NOCASE ASC, ${DatabaseConstants.columnId} ASC',
      );
      return maps.map((map) => PublicationMapper.fromMap(map)).toList();
    } on DatabaseException catch (e) {
      throw PublicationPersistenceException(
        'Error de persistencia en SQLite al buscar publicaciones activas por nombre exacto.',
        e,
      );
    } catch (e) {
      if (e is ArgumentError) rethrow;
      throw PublicationPersistenceException(
        'Error inesperado al buscar publicaciones activas por nombre exacto en la base de datos.',
        e,
      );
    }
  }

  String _escapeLike(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
  }
}
