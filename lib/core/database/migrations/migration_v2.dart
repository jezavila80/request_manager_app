import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class MigrationV2 {
  static Future<void> execute(Database db) async {
    // 1. Create requests table
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableRequests} (
          ${DatabaseConstants.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${DatabaseConstants.columnRequestedBy} TEXT NOT NULL,
          ${DatabaseConstants.columnNotes} TEXT,
          ${DatabaseConstants.columnCreatedAt} TEXT NOT NULL,
          ${DatabaseConstants.columnUpdatedAt} TEXT NOT NULL,

          CHECK (TRIM(${DatabaseConstants.columnRequestedBy}) <> '')
      );
    ''');

    // 2. Create request_items table with foreign keys and check constraints
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableRequestItems} (
          ${DatabaseConstants.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${DatabaseConstants.columnRequestId} INTEGER NOT NULL,
          ${DatabaseConstants.columnPublicationId} INTEGER NOT NULL,
          ${DatabaseConstants.columnQuantityRequested} INTEGER NOT NULL,
          ${DatabaseConstants.columnQuantityFulfilled} INTEGER NOT NULL DEFAULT 0,

          FOREIGN KEY (${DatabaseConstants.columnRequestId})
              REFERENCES ${DatabaseConstants.tableRequests}(${DatabaseConstants.columnId})
              ON DELETE CASCADE,

          FOREIGN KEY (${DatabaseConstants.columnPublicationId})
              REFERENCES ${DatabaseConstants.tablePublications}(${DatabaseConstants.columnId})
              ON DELETE RESTRICT,

          CHECK (${DatabaseConstants.columnQuantityRequested} > 0),

          CHECK (
              ${DatabaseConstants.columnQuantityFulfilled} >= 0
              AND ${DatabaseConstants.columnQuantityFulfilled} <= ${DatabaseConstants.columnQuantityRequested}
          ),

          CONSTRAINT uq_request_items_request_publication UNIQUE (
              ${DatabaseConstants.columnRequestId},
              ${DatabaseConstants.columnPublicationId}
          )
      );
    ''');

    // 3. Create indices for foreign keys to optimize joins and queries
    await db.execute('''
      CREATE INDEX idx_request_items_request_id
      ON ${DatabaseConstants.tableRequestItems}(${DatabaseConstants.columnRequestId});
    ''');

    await db.execute('''
      CREATE INDEX idx_request_items_publication_id
      ON ${DatabaseConstants.tableRequestItems}(${DatabaseConstants.columnPublicationId});
    ''');
  }
}
