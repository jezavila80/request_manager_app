import 'package:sqflite/sqflite.dart';
import 'database_constants.dart';

class DatabaseSeeder {
  static Future<void> seedIfEmpty(Database db) async {
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseConstants.tablePublications}',
    );
    final count = Sqflite.firstIntValue(countResult) ?? 0;

    if (count > 0) return;

    final now = DateTime.now().toIso8601String();

    final testItems = [
      {
        DatabaseConstants.columnCode: 'RBI-8',
        DatabaseConstants.columnName: 'Biblia Letra Grande',
        DatabaseConstants.columnType: 'Libro',
        DatabaseConstants.columnDescription: null,
      },
      {
        DatabaseConstants.columnCode: 'RBI-12',
        DatabaseConstants.columnName: 'Biblia de Estudio',
        DatabaseConstants.columnType: 'Libro',
        DatabaseConstants.columnDescription: null,
      },
      {
        DatabaseConstants.columnCode: 'RL-12',
        DatabaseConstants.columnName: 'Revista La Atalaya',
        DatabaseConstants.columnType: 'Revista',
        DatabaseConstants.columnDescription: null,
      },
      {
        DatabaseConstants.columnCode: 'W26-1',
        DatabaseConstants.columnName: 'Cuaderno de Trabajo 2026',
        DatabaseConstants.columnType: 'Cuaderno',
        DatabaseConstants.columnDescription: null,
      },
      {
        DatabaseConstants.columnCode: 'FOL-01',
        DatabaseConstants.columnName: 'Folleto Informativo',
        DatabaseConstants.columnType: 'Folleto',
        DatabaseConstants.columnDescription: null,
      },
      {
        DatabaseConstants.columnCode: 'TRAT-03',
        DatabaseConstants.columnName: 'Tratado Esperanza para el Futuro',
        DatabaseConstants.columnType: 'Tratado',
        DatabaseConstants.columnDescription: null,
      },
      {
        DatabaseConstants.columnCode: 'BOL-02',
        DatabaseConstants.columnName: 'Boletín Mensual',
        DatabaseConstants.columnType: 'Boletín',
        DatabaseConstants.columnDescription: null,
      },
      {
        DatabaseConstants.columnCode: null,
        DatabaseConstants.columnName: 'Biblia por identificar',
        DatabaseConstants.columnType: null,
        DatabaseConstants.columnDescription: 'Borrador sin tipo definido',
      },
      {
        DatabaseConstants.columnCode: 'TEMP-01',
        DatabaseConstants.columnName: 'Publicación especial pendiente',
        DatabaseConstants.columnType: null,
        DatabaseConstants.columnDescription: 'Borrador con código temporal',
      },
      {
        DatabaseConstants.columnCode: 'CART-01',
        DatabaseConstants.columnName: 'Cartel de campaña',
        DatabaseConstants.columnType: 'Cartel',
        DatabaseConstants.columnDescription: null,
      },
      {
        DatabaseConstants.columnCode: 'GUIA-01',
        DatabaseConstants.columnName: 'Guía de estudio para familias',
        DatabaseConstants.columnType: 'Guía',
        DatabaseConstants.columnDescription: null,
      },
      {
        DatabaseConstants.columnCode: 'LIB-EXT-2026',
        DatabaseConstants.columnName:
            'Manual de capacitación para responsables de publicaciones',
        DatabaseConstants.columnType: 'Manual',
        DatabaseConstants.columnDescription: null,
      },
      {
        DatabaseConstants.columnCode: 'RBI-JOV',
        DatabaseConstants.columnName: 'Biblia de Estudio para Jóvenes',
        DatabaseConstants.columnType: 'Libro',
        DatabaseConstants.columnDescription: null,
      },
      {
        DatabaseConstants.columnCode: 'REV-ESP',
        DatabaseConstants.columnName: 'Revista Especial de Asamblea',
        DatabaseConstants.columnType: 'Revista',
        DatabaseConstants.columnDescription: null,
      },
    ];

    final batch = db.batch();
    for (final item in testItems) {
      batch.insert(
        DatabaseConstants.tablePublications,
        {
          DatabaseConstants.columnCode: item[DatabaseConstants.columnCode],
          DatabaseConstants.columnName: item[DatabaseConstants.columnName],
          DatabaseConstants.columnDescription:
              item[DatabaseConstants.columnDescription],
          DatabaseConstants.columnType: item[DatabaseConstants.columnType],
          DatabaseConstants.columnSizeState: DatabaseConstants.stateUndefined,
          DatabaseConstants.columnSizeValue: null,
          DatabaseConstants.columnVersionState:
              DatabaseConstants.stateUndefined,
          DatabaseConstants.columnVersionValue: null,
          DatabaseConstants.columnIsActive: 1,
          DatabaseConstants.columnCreatedAt: now,
          DatabaseConstants.columnUpdatedAt: now,
        },
      );
    }
    await batch.commit(noResult: true);
  }
}
