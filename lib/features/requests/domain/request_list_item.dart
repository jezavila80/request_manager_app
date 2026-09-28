import '../../../../core/time/app_date_time.dart';
import 'request_fulfillment_status.dart';

/// Read model / projection representing a summary of a request for list views.
///
/// Immutable domain model containing aggregated data resolved from SQLite
/// without reconstructing complete [Request] or [Requester] aggregates.
class RequestListItem {
  final int requestId;
  final int requesterId;
  final String requesterName;
  final DateTime createdAt;
  final int publicationCount;
  final int quantityRequested;
  final int quantityFulfilled;

  /// Factory constructor applying invariants.
  RequestListItem({
    required this.requestId,
    required this.requesterId,
    required String requesterName,
    required DateTime createdAt,
    required this.publicationCount,
    required this.quantityRequested,
    required this.quantityFulfilled,
  })  : requesterName = requesterName.trim(),
        createdAt = AppDateTime.normalizeUtc(createdAt) {
    if (requestId <= 0) {
      throw ArgumentError('El ID del pedido debe ser mayor a cero.');
    }
    if (requesterId <= 0) {
      throw ArgumentError('El ID del solicitante debe ser mayor a cero.');
    }
    if (this.requesterName.isEmpty) {
      throw ArgumentError('El nombre del solicitante no puede estar vacío.');
    }
    if (publicationCount < 0) {
      throw ArgumentError('El número de publicaciones no puede ser negativo.');
    }
    if (quantityRequested < 0) {
      throw ArgumentError('La cantidad solicitada no puede ser negativa.');
    }
    if (quantityFulfilled < 0) {
      throw ArgumentError('La cantidad surtida no puede ser negativa.');
    }
    if (quantityFulfilled > quantityRequested) {
      throw ArgumentError(
        'La cantidad surtida ($quantityFulfilled) no puede exceder la cantidad solicitada ($quantityRequested).',
      );
    }
  }

  /// Calculates fulfillment status using the canonical domain rule.
  RequestFulfillmentStatus get fulfillmentStatus =>
      calculateRequestFulfillmentStatus(
        itemCount: publicationCount,
        quantityRequested: quantityRequested,
        quantityFulfilled: quantityFulfilled,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestListItem &&
          runtimeType == other.runtimeType &&
          requestId == other.requestId &&
          requesterId == other.requesterId &&
          requesterName == other.requesterName &&
          createdAt == other.createdAt &&
          publicationCount == other.publicationCount &&
          quantityRequested == other.quantityRequested &&
          quantityFulfilled == other.quantityFulfilled;

  @override
  int get hashCode => Object.hash(
        requestId,
        requesterId,
        requesterName,
        createdAt,
        publicationCount,
        quantityRequested,
        quantityFulfilled,
      );

  @override
  String toString() =>
      'RequestListItem(requestId: $requestId, requesterId: $requesterId, '
      'requesterName: "$requesterName", createdAt: $createdAt, '
      'publicationCount: $publicationCount, quantityRequested: $quantityRequested, '
      'quantityFulfilled: $quantityFulfilled, status: $fulfillmentStatus)';
}
