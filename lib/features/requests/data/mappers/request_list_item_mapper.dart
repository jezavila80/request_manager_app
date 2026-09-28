import '../../../../core/time/app_date_time.dart';
import '../../domain/request_list_item.dart';

/// Mapper to transform SQL query rows into [RequestListItem] domain read models.
class RequestListItemMapper {
  static const String columnRequestId = 'request_id';
  static const String columnRequesterId = 'requester_id';
  static const String columnRequesterName = 'requester_name';
  static const String columnCreatedAt = 'created_at';
  static const String columnPublicationCount = 'publication_count';
  static const String columnQuantityRequested = 'quantity_requested';
  static const String columnQuantityFulfilled = 'quantity_fulfilled';

  static RequestListItem fromMap(Map<String, Object?> map) {
    final requestId = (map[columnRequestId] as num?)?.toInt();
    final requesterId = (map[columnRequesterId] as num?)?.toInt();
    final requesterName = map[columnRequesterName] as String?;
    final createdAtStr = map[columnCreatedAt] as String?;
    final publicationCount =
        (map[columnPublicationCount] as num?)?.toInt() ?? 0;
    final quantityRequested =
        (map[columnQuantityRequested] as num?)?.toInt() ?? 0;
    final quantityFulfilled =
        (map[columnQuantityFulfilled] as num?)?.toInt() ?? 0;

    if (requestId == null) {
      throw const FormatException(
          'Falta la columna obligatoria request_id en la fila.');
    }
    if (requesterId == null) {
      throw const FormatException(
          'Falta la columna obligatoria requester_id en la fila.');
    }
    if (requesterName == null || requesterName.trim().isEmpty) {
      throw const FormatException(
          'Falta la columna obligatoria requester_name en la fila.');
    }
    if (createdAtStr == null || createdAtStr.trim().isEmpty) {
      throw const FormatException(
          'Falta la columna obligatoria created_at en la fila.');
    }

    final createdAt = AppDateTime.fromStorage(createdAtStr);

    return RequestListItem(
      requestId: requestId,
      requesterId: requesterId,
      requesterName: requesterName,
      createdAt: createdAt,
      publicationCount: publicationCount,
      quantityRequested: quantityRequested,
      quantityFulfilled: quantityFulfilled,
    );
  }
}
