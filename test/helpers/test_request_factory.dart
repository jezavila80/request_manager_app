import 'package:request_manager_app/features/requests/domain/request.dart';
import 'package:request_manager_app/features/requests/domain/request_item.dart';

/// Test helper to construct [Request] instances with deterministic UTC timestamps.
Request createTestRequest({
  int? id,
  required String requestedBy,
  List<RequestItem> items = const [],
  String? notes,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final defaultTimestamp = DateTime.utc(2026, 9, 7, 10, 0);
  final effectiveCreatedAt = createdAt ?? defaultTimestamp;
  return Request(
    id: id,
    requestedBy: requestedBy,
    items: items,
    notes: notes,
    createdAt: effectiveCreatedAt,
    updatedAt: updatedAt ?? effectiveCreatedAt,
  );
}
