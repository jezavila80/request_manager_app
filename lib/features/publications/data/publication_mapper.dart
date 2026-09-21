import '../../../core/database/database_constants.dart';
import '../../../core/time/app_date_time.dart';
import '../domain/publication.dart';
import '../domain/tri_state_value.dart';

class PublicationMapper {
  static Map<String, Object?> toMap(Publication publication) {
    String sizeState;
    switch (publication.size.state) {
      case TriState.sinDefinir:
        sizeState = DatabaseConstants.stateUndefined;
        break;
      case TriState.noAplica:
        sizeState = DatabaseConstants.stateNotApplicable;
        break;
      case TriState.conValor:
        sizeState = DatabaseConstants.stateValue;
        break;
    }

    String versionState;
    switch (publication.version.state) {
      case TriState.sinDefinir:
        versionState = DatabaseConstants.stateUndefined;
        break;
      case TriState.noAplica:
        versionState = DatabaseConstants.stateNotApplicable;
        break;
      case TriState.conValor:
        versionState = DatabaseConstants.stateValue;
        break;
    }

    return {
      if (publication.id != null) DatabaseConstants.columnId: publication.id,
      DatabaseConstants.columnCode: publication.code,
      DatabaseConstants.columnName: publication.name,
      DatabaseConstants.columnDescription: publication.description,
      DatabaseConstants.columnType: publication.type,
      DatabaseConstants.columnSizeState: sizeState,
      DatabaseConstants.columnSizeValue: publication.size.value,
      DatabaseConstants.columnVersionState: versionState,
      DatabaseConstants.columnVersionValue: publication.version.value,
      DatabaseConstants.columnIsActive: publication.isActive ? 1 : 0,
      DatabaseConstants.columnCreatedAt:
          AppDateTime.toStorage(publication.createdAt),
      DatabaseConstants.columnUpdatedAt:
          AppDateTime.toStorage(publication.updatedAt),
    };
  }

  static Publication fromMap(Map<String, Object?> map) {
    final id = map[DatabaseConstants.columnId] as int?;
    final code = map[DatabaseConstants.columnCode] as String?;
    final name = map[DatabaseConstants.columnName] as String? ?? '';
    final description = map[DatabaseConstants.columnDescription] as String?;
    final type = map[DatabaseConstants.columnType] as String?;
    final isActive = (map[DatabaseConstants.columnIsActive] as int? ?? 1) == 1;

    final createdAtStr = map[DatabaseConstants.columnCreatedAt] as String?;
    final updatedAtStr = map[DatabaseConstants.columnUpdatedAt] as String?;

    if (createdAtStr == null || createdAtStr.trim().isEmpty) {
      throw const FormatException(
          'Falta la columna obligatoria created_at en la publicación.');
    }
    if (updatedAtStr == null || updatedAtStr.trim().isEmpty) {
      throw const FormatException(
          'Falta la columna obligatoria updated_at en la publicación.');
    }

    final createdAt = AppDateTime.fromStorage(createdAtStr);
    final updatedAt = AppDateTime.fromStorage(updatedAtStr);

    final sizeStateStr = map[DatabaseConstants.columnSizeState] as String? ??
        DatabaseConstants.stateUndefined;
    final sizeValue = map[DatabaseConstants.columnSizeValue] as String?;
    TriStateValue<String> size;
    switch (sizeStateStr) {
      case DatabaseConstants.stateNotApplicable:
        size = const TriStateValue.noAplica();
        break;
      case DatabaseConstants.stateValue:
        size = TriStateValue.conValor(sizeValue ?? '');
        break;
      case DatabaseConstants.stateUndefined:
      default:
        size = const TriStateValue.sinDefinir();
        break;
    }

    final versionStateStr =
        map[DatabaseConstants.columnVersionState] as String? ??
            DatabaseConstants.stateUndefined;
    final versionValue = map[DatabaseConstants.columnVersionValue] as String?;
    TriStateValue<String> version;
    switch (versionStateStr) {
      case DatabaseConstants.stateNotApplicable:
        version = const TriStateValue.noAplica();
        break;
      case DatabaseConstants.stateValue:
        version = TriStateValue.conValor(versionValue ?? '');
        break;
      case DatabaseConstants.stateUndefined:
      default:
        version = const TriStateValue.sinDefinir();
        break;
    }

    return Publication(
      id: id,
      code: code,
      name: name,
      description: description,
      type: type,
      size: size,
      version: version,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
