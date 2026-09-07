import '../../../../core/database/database_constants.dart';
import '../../domain/request_item.dart';

class RequestItemMapper {
  static Map<String, Object?> toMap(
    RequestItem item, {
    required int requestId,
  }) {
    return {
      if (item.id != null) DatabaseConstants.columnId: item.id,
      DatabaseConstants.columnRequestId: requestId,
      DatabaseConstants.columnPublicationId: item.publicationId,
      DatabaseConstants.columnQuantityRequested: item.quantityRequested,
      DatabaseConstants.columnQuantityFulfilled: item.quantityFulfilled,
    };
  }

  static RequestItem fromMap(Map<String, Object?> map) {
    final id = map[DatabaseConstants.columnId] as int?;
    final publicationId =
        map[DatabaseConstants.columnPublicationId] as int? ?? 0;
    final quantityRequested =
        map[DatabaseConstants.columnQuantityRequested] as int? ?? 0;
    final quantityFulfilled =
        map[DatabaseConstants.columnQuantityFulfilled] as int? ?? 0;

    return RequestItem(
      id: id,
      publicationId: publicationId,
      quantityRequested: quantityRequested,
      quantityFulfilled: quantityFulfilled,
    );
  }
}
