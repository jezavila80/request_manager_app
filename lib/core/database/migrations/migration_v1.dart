import 'package:sqflite/sqflite.dart';

class MigrationV1 {
  static Future<void> execute(Database db) async {
    await db.execute('''
      CREATE TABLE publications (
          id INTEGER PRIMARY KEY AUTOINCREMENT,

          code TEXT,
          name TEXT NOT NULL,
          description TEXT,
          type TEXT,

          size_value TEXT,
          size_state TEXT NOT NULL DEFAULT 'undefined',

          version_value TEXT,
          version_state TEXT NOT NULL DEFAULT 'undefined',

          is_active INTEGER NOT NULL DEFAULT 1,

          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,

          CHECK (TRIM(name) <> ''),

          CHECK (
              size_state IN ('undefined', 'value', 'not_applicable')
          ),

          CHECK (
              version_state IN ('undefined', 'value', 'not_applicable')
          ),

          CHECK (
              (
                  size_state = 'value'
                  AND size_value IS NOT NULL
                  AND TRIM(size_value) <> ''
              )
              OR
              (
                  size_state IN ('undefined', 'not_applicable')
                  AND size_value IS NULL
              )
          ),

          CHECK (
              (
                  version_state = 'value'
                  AND version_value IS NOT NULL
                  AND TRIM(version_value) <> ''
              )
              OR
              (
                  version_state IN ('undefined', 'not_applicable')
                  AND version_value IS NULL
              )
          ),

          CHECK (is_active IN (0, 1))
      );
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX idx_publications_code_unique
      ON publications(code COLLATE NOCASE)
      WHERE code IS NOT NULL AND TRIM(code) <> '';
    ''');
  }
}
