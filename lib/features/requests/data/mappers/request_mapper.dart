import '../../../../core/database/database_constants.dart';
import '../../../../core/time/app_date_time.dart';
import '../../domain/request.dart';
import '../../domain/request_item.dart';

class RequestMapper {
  static Map<String, Object?> toMap(Request request) {
    return {
      if (request.id != null) DatabaseConstants.columnId: request.id,
      DatabaseConstants.columnRequestedBy: request.requestedBy,
      DatabaseConstants.columnNotes: request.notes,
      DatabaseConstants.columnCreatedAt:
          AppDateTime.toStorage(request.createdAt),
      DatabaseConstants.columnUpdatedAt:
          AppDateTime.toStorage(request.updatedAt),
    };
  }

  static Request fromMap(
    Map<String, Object?> map, {
    List<RequestItem> items = const [],
  }) {
    final id = map[DatabaseConstants.columnId] as int?;
    final requestedBy =
        map[DatabaseConstants.columnRequestedBy] as String? ?? '';
    final notes = map[DatabaseConstants.columnNotes] as String?;
    final createdAtStr = map[DatabaseConstants.columnCreatedAt] as String?;
    final updatedAtStr = map[DatabaseConstants.columnUpdatedAt] as String?;

    if (createdAtStr == null || createdAtStr.trim().isEmpty) {
      throw const FormatException(
          'Falta la columna obligatoria created_at en la solicitud.');
    }
    if (updatedAtStr == null || updatedAtStr.trim().isEmpty) {
      throw const FormatException(
          'Falta la columna obligatoria updated_at en la solicitud.');
    }

    final createdAt = AppDateTime.fromStorage(createdAtStr);
    final updatedAt = AppDateTime.fromStorage(updatedAtStr);

    return Request(
      id: id,
      requestedBy: requestedBy,
      items: items,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
