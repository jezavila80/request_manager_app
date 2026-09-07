import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'database_constants.dart';
import 'migrations/migration_v1.dart';
import 'migrations/migration_v2.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(DatabaseConstants.databaseName);
    return _database!;
  }

  /// Initializes a database for testing purposes.
  /// Allows passing a custom [path] (e.g. in-memory or temp file) and an optional custom [factory].
  Future<Database> initDatabaseForTesting(String path,
      {DatabaseFactory? factory}) async {
    if (_database != null) {
      await close();
    }

    final options = OpenDatabaseOptions(
      version: DatabaseConstants.databaseVersion,
      onConfigure: _configureDB,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );

    if (factory != null) {
      _database = await factory.openDatabase(path, options: options);
    } else {
      _database = await openDatabase(
        path,
        version: DatabaseConstants.databaseVersion,
        onConfigure: _configureDB,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    }
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final pathString = join(dbPath, filePath);

    return await openDatabase(
      pathString,
      version: DatabaseConstants.databaseVersion,
      onConfigure: _configureDB,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _configureDB(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _createDB(Database db, int version) async {
    if (version >= 1) {
      await MigrationV1.execute(db);
    }
    if (version >= 2) {
      await MigrationV2.execute(db);
    }
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await MigrationV2.execute(db);
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
