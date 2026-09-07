import '../../../../core/database/database_constants.dart';
import '../../domain/request.dart';
import '../../domain/request_item.dart';

class RequestMapper {
  static Map<String, Object?> toMap(Request request) {
    return {
      if (request.id != null) DatabaseConstants.columnId: request.id,
      DatabaseConstants.columnRequestedBy: request.requestedBy,
      DatabaseConstants.columnNotes: request.notes,
      DatabaseConstants.columnCreatedAt: request.createdAt.toIso8601String(),
      DatabaseConstants.columnUpdatedAt: request.updatedAt.toIso8601String(),
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

    return Request(
      id: id,
      requestedBy: requestedBy,
      items: items,
      notes: notes,
      createdAt:
          createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now(),
      updatedAt:
          updatedAtStr != null ? DateTime.parse(updatedAtStr) : DateTime.now(),
    );
  }
}
