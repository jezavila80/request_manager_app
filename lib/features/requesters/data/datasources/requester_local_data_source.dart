import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_constants.dart';
import '../../domain/requester.dart';
import '../../domain/services/requester_name_normalizer.dart';
import '../mappers/requester_mapper.dart';

abstract interface class RequesterLocalDataSource {
  Future<Requester> create(Requester requester);
  Future<Requester?> getById(int id);
  Future<Requester?> findByNormalizedName(String normalizedName);
  Future<List<Requester>> searchActiveByName(String query, {int limit = 20});
  Future<List<Requester>> getAll();
}

class RequesterLocalDataSourceImpl implements RequesterLocalDataSource {
  final AppDatabase _appDatabase;

  RequesterLocalDataSourceImpl({AppDatabase? appDatabase})
      : _appDatabase = appDatabase ?? AppDatabase.instance;

  Future<Database> get _db async => await _appDatabase.database;

  @override
  Future<Requester> create(Requester requester) async {
    final db = await _db;
    final map = RequesterMapper.toMap(requester);
    final id = await db.insert(
      DatabaseConstants.tableRequesters,
      map,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return requester.copyWith(id: id);
  }

  @override
  Future<Requester?> getById(int id) async {
    final db = await _db;
    final maps = await db.query(
      DatabaseConstants.tableRequesters,
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return RequesterMapper.fromMap(maps.first);
  }

  @override
  Future<Requester?> findByNormalizedName(String normalizedName) async {
    final db = await _db;
    final maps = await db.query(
      DatabaseConstants.tableRequesters,
      where: '${DatabaseConstants.columnNormalizedName} = ?',
      whereArgs: [normalizedName],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return RequesterMapper.fromMap(maps.first);
  }

  @override
  Future<List<Requester>> searchActiveByName(String query,
      {int limit = 20}) async {
    final db = await _db;
    final normalizedQuery = RequesterNameNormalizer.normalize(query);
    if (normalizedQuery.isEmpty) return [];

    final maps = await db.query(
      DatabaseConstants.tableRequesters,
      where:
          '${DatabaseConstants.columnIsActive} = 1 AND ${DatabaseConstants.columnNormalizedName} LIKE ?',
      whereArgs: ['%$normalizedQuery%'],
      orderBy: '${DatabaseConstants.columnName} ASC',
      limit: limit,
    );

    return maps.map(RequesterMapper.fromMap).toList();
  }

  @override
  Future<List<Requester>> getAll() async {
    final db = await _db;
    final maps = await db.query(
      DatabaseConstants.tableRequesters,
      orderBy: '${DatabaseConstants.columnName} ASC',
    );
    return maps.map(RequesterMapper.fromMap).toList();
  }
}
