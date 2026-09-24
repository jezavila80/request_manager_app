import 'package:sqflite/sqflite.dart';
import '../../../../features/requesters/domain/services/requester_name_cleaner.dart';
import '../../../../features/requesters/domain/services/requester_name_normalizer.dart';
import '../database_constants.dart';

class MigrationV3 {
  static Future<void> execute(Database db) async {
    // 1. Create requesters table if not exists
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableRequesters} (
          ${DatabaseConstants.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${DatabaseConstants.columnName} TEXT NOT NULL,
          ${DatabaseConstants.columnNormalizedName} TEXT NOT NULL,
          ${DatabaseConstants.columnIsActive} INTEGER NOT NULL DEFAULT 1,
          ${DatabaseConstants.columnCreatedAt} TEXT NOT NULL,
          ${DatabaseConstants.columnUpdatedAt} TEXT NOT NULL,

          CONSTRAINT uq_requesters_normalized_name UNIQUE (${DatabaseConstants.columnNormalizedName}),
          CHECK (TRIM(${DatabaseConstants.columnName}) <> ''),
          CHECK (TRIM(${DatabaseConstants.columnNormalizedName}) <> ''),
          CHECK (${DatabaseConstants.columnIsActive} IN (0, 1))
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_requesters_normalized_name
      ON ${DatabaseConstants.tableRequesters}(${DatabaseConstants.columnNormalizedName});
    ''');

    // 2. Check if requests table has column requested_by that needs migration
    final tableInfo = await db
        .rawQuery('PRAGMA table_info(${DatabaseConstants.tableRequests});');
    final colNames = tableInfo.map((c) => c['name'] as String).toSet();

    if (colNames.contains(DatabaseConstants.columnRequestedBy)) {
      // Temporarily disable foreign keys during table recreation
      await db.execute('PRAGMA foreign_keys = OFF;');

      // 3. Read existing requests deterministically ordered by id ASC
      final existingRequests = await db.rawQuery('''
        SELECT 
          ${DatabaseConstants.columnId},
          ${DatabaseConstants.columnRequestedBy},
          ${DatabaseConstants.columnNotes},
          ${DatabaseConstants.columnCreatedAt},
          ${DatabaseConstants.columnUpdatedAt}
        FROM ${DatabaseConstants.tableRequests}
        ORDER BY ${DatabaseConstants.columnId} ASC;
      ''');

      final Map<int, int> requestToRequesterMap = {};

      for (final reqRow in existingRequests) {
        final reqId = reqRow[DatabaseConstants.columnId] as int;
        final rawRequestedBy =
            reqRow[DatabaseConstants.columnRequestedBy] as String;
        final cleanedName = RequesterNameCleaner.clean(rawRequestedBy);
        final normalized = RequesterNameNormalizer.normalize(cleanedName);

        // Check if a Requester with this normalized_name already exists
        final existingRequesters = await db.rawQuery(
          'SELECT ${DatabaseConstants.columnId} FROM ${DatabaseConstants.tableRequesters} WHERE ${DatabaseConstants.columnNormalizedName} = ? LIMIT 1;',
          [normalized],
        );

        int requesterId;
        if (existingRequesters.isNotEmpty) {
          requesterId =
              existingRequesters.first[DatabaseConstants.columnId] as int;
        } else {
          // Insert the first valid visible representation found deterministically
          requesterId = await db.rawInsert(
            '''
            INSERT INTO ${DatabaseConstants.tableRequesters} (
              ${DatabaseConstants.columnName},
              ${DatabaseConstants.columnNormalizedName},
              ${DatabaseConstants.columnIsActive},
              ${DatabaseConstants.columnCreatedAt},
              ${DatabaseConstants.columnUpdatedAt}
            ) VALUES (?, ?, 1, ?, ?);
            ''',
            [
              cleanedName,
              normalized,
              reqRow[DatabaseConstants.columnCreatedAt],
              reqRow[DatabaseConstants.columnUpdatedAt],
            ],
          );
        }

        requestToRequesterMap[reqId] = requesterId;
      }

      // 4. Create new requests table with requester_id
      await db.execute('''
        CREATE TABLE requests_v3 (
            ${DatabaseConstants.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
            ${DatabaseConstants.columnRequesterId} INTEGER NOT NULL,
            ${DatabaseConstants.columnNotes} TEXT,
            ${DatabaseConstants.columnCreatedAt} TEXT NOT NULL,
            ${DatabaseConstants.columnUpdatedAt} TEXT NOT NULL,

            FOREIGN KEY (${DatabaseConstants.columnRequesterId})
                REFERENCES ${DatabaseConstants.tableRequesters}(${DatabaseConstants.columnId})
                ON DELETE RESTRICT
        );
      ''');

      // 5. Copy data into requests_v3 preserving original request IDs
      for (final reqRow in existingRequests) {
        final reqId = reqRow[DatabaseConstants.columnId] as int;
        final requesterId = requestToRequesterMap[reqId]!;
        await db.rawInsert(
          '''
          INSERT INTO requests_v3 (
            ${DatabaseConstants.columnId},
            ${DatabaseConstants.columnRequesterId},
            ${DatabaseConstants.columnNotes},
            ${DatabaseConstants.columnCreatedAt},
            ${DatabaseConstants.columnUpdatedAt}
          ) VALUES (?, ?, ?, ?, ?);
          ''',
          [
            reqId,
            requesterId,
            reqRow[DatabaseConstants.columnNotes],
            reqRow[DatabaseConstants.columnCreatedAt],
            reqRow[DatabaseConstants.columnUpdatedAt],
          ],
        );
      }

      // Backup existing request_items to guarantee preservation during requests table alteration
      final existingItems = await db.rawQuery('''
        SELECT 
          ${DatabaseConstants.columnId},
          ${DatabaseConstants.columnRequestId},
          ${DatabaseConstants.columnPublicationId},
          ${DatabaseConstants.columnQuantityRequested},
          ${DatabaseConstants.columnQuantityFulfilled}
        FROM ${DatabaseConstants.tableRequestItems}
        ORDER BY ${DatabaseConstants.columnId} ASC;
      ''');

      // 6. Drop old requests table and rename requests_v3 to requests
      await db.execute('DROP TABLE ${DatabaseConstants.tableRequests};');
      await db.execute(
          'ALTER TABLE requests_v3 RENAME TO ${DatabaseConstants.tableRequests};');

      // Restore request_items if CASCADE was triggered by SQLite
      final remainingCountResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseConstants.tableRequestItems};',
      );
      final remainingCount = Sqflite.firstIntValue(remainingCountResult) ?? 0;
      if (remainingCount == 0 && existingItems.isNotEmpty) {
        for (final itemRow in existingItems) {
          await db.rawInsert(
            '''
            INSERT INTO ${DatabaseConstants.tableRequestItems} (
              ${DatabaseConstants.columnId},
              ${DatabaseConstants.columnRequestId},
              ${DatabaseConstants.columnPublicationId},
              ${DatabaseConstants.columnQuantityRequested},
              ${DatabaseConstants.columnQuantityFulfilled}
            ) VALUES (?, ?, ?, ?, ?);
            ''',
            [
              itemRow[DatabaseConstants.columnId],
              itemRow[DatabaseConstants.columnRequestId],
              itemRow[DatabaseConstants.columnPublicationId],
              itemRow[DatabaseConstants.columnQuantityRequested],
              itemRow[DatabaseConstants.columnQuantityFulfilled],
            ],
          );
        }
      }

      // 7. Re-enable foreign keys and verify integrity
      await db.execute('PRAGMA foreign_keys = ON;');
      final fkViolations = await db.rawQuery('PRAGMA foreign_key_check;');
      if (fkViolations.isNotEmpty) {
        throw StateError(
          'Error de integridad referencial durante la migración v3: $fkViolations',
        );
      }
    }
  }
}
