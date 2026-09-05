import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_constants.dart';

/// Development/Demo seed utility specifically created for testing
/// database persistence across app process terminations and device reboots.
///
/// TEMPORARY / DEVELOPMENT ONLY.
class PublicationPersistenceValidationSeed {
  static const List<String> seedCodes = [
    'nwtls-S',
    'lffi-S',
    'nwtpkt-S',
    'T-31-S',
    'mvpfbc2-S',
  ];

  static Future<int> loadSeed(Database db) async {
    final now = DateTime.now().toIso8601String();
    int insertedCount = 0;

    final demoItems = [
      {
        DatabaseConstants.columnCode: 'nwtls-S',
        DatabaseConstants.columnName:
            'La Biblia. Traducción del Nuevo Mundo (edición grande)',
        DatabaseConstants.columnDescription:
            'La Biblia. Traducción del Nuevo Mundo (edición grande)',
        DatabaseConstants.columnType: 'Libro',
        DatabaseConstants.columnSizeState: DatabaseConstants.stateValue,
        DatabaseConstants.columnSizeValue: 'Grande',
        DatabaseConstants.columnVersionState: DatabaseConstants.stateValue,
        DatabaseConstants.columnVersionValue: 'Edición Grande',
        DatabaseConstants.columnIsActive: 1,
      },
      {
        DatabaseConstants.columnCode: 'lffi-S',
        DatabaseConstants.columnName:
            '¡Disfrute de la vida para siempre! Introducción a las enseñanzas de la Biblia',
        DatabaseConstants.columnDescription:
            '¡Disfrute de la vida para siempre! Introducción a las enseñanzas de la Biblia',
        DatabaseConstants.columnType: 'Folleto',
        DatabaseConstants.columnSizeState: DatabaseConstants.stateNotApplicable,
        DatabaseConstants.columnSizeValue: null,
        DatabaseConstants.columnVersionState:
            DatabaseConstants.stateNotApplicable,
        DatabaseConstants.columnVersionValue: null,
        DatabaseConstants.columnIsActive: 1,
      },
      {
        DatabaseConstants.columnCode: 'nwtpkt-S',
        DatabaseConstants.columnName:
            'La Biblia. Traducción del Nuevo Mundo (edición de bolsillo)',
        DatabaseConstants.columnDescription:
            'La Biblia. Traducción del Nuevo Mundo (edición de bolsillo)',
        DatabaseConstants.columnType: 'Libro',
        DatabaseConstants.columnSizeState: DatabaseConstants.stateValue,
        DatabaseConstants.columnSizeValue: 'Bolsillo',
        DatabaseConstants.columnVersionState: DatabaseConstants.stateValue,
        DatabaseConstants.columnVersionValue: 'Edición de bolsillo',
        DatabaseConstants.columnIsActive: 1,
      },
      {
        DatabaseConstants.columnCode: 'T-31-S',
        DatabaseConstants.columnName: '¿Cómo ve el futuro? (tratado núm. 31)',
        DatabaseConstants.columnDescription:
            '¿Cómo ve el futuro? (tratado núm. 31)',
        DatabaseConstants.columnType: 'Tratado',
        DatabaseConstants.columnSizeState: DatabaseConstants.stateNotApplicable,
        DatabaseConstants.columnSizeValue: null,
        DatabaseConstants.columnVersionState: DatabaseConstants.stateValue,
        DatabaseConstants.columnVersionValue: 'Bolsillo',
        DatabaseConstants.columnIsActive: 1,
      },
      {
        DatabaseConstants.columnCode: 'mvpfbc2-S',
        DatabaseConstants.columnName:
            'Cursos bíblicos gratuitos [cartel vertical magnético] - Divulgar los cursos bíblicos virtuales',
        DatabaseConstants.columnDescription:
            'Cursos bíblicos gratuitos [cartel vertical magnético] - Divulgar los cursos bíblicos virtuales',
        DatabaseConstants.columnType: null,
        DatabaseConstants.columnSizeState: DatabaseConstants.stateUndefined,
        DatabaseConstants.columnSizeValue: null,
        DatabaseConstants.columnVersionState:
            DatabaseConstants.stateNotApplicable,
        DatabaseConstants.columnVersionValue: null,
        DatabaseConstants.columnIsActive: 1,
      },
    ];

    for (final item in demoItems) {
      final code = item[DatabaseConstants.columnCode] as String;
      final existing = await db.query(
        DatabaseConstants.tablePublications,
        columns: [DatabaseConstants.columnId],
        where: '${DatabaseConstants.columnCode} = ? COLLATE NOCASE',
        whereArgs: [code],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        continue;
      }

      await db.insert(
        DatabaseConstants.tablePublications,
        {
          ...item,
          DatabaseConstants.columnCreatedAt: now,
          DatabaseConstants.columnUpdatedAt: now,
        },
      );
      insertedCount++;
    }

    return insertedCount;
  }

  static Future<int> clearSeed(Database db) async {
    int deletedCount = 0;
    for (final code in seedCodes) {
      final rows = await db.delete(
        DatabaseConstants.tablePublications,
        where: '${DatabaseConstants.columnCode} = ? COLLATE NOCASE',
        whereArgs: [code],
      );
      deletedCount += rows;
    }
    return deletedCount;
  }
}
