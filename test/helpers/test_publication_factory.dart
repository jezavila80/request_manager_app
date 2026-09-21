import 'package:request_manager_app/features/publications/domain/publication.dart';
import 'package:request_manager_app/features/publications/domain/tri_state_value.dart';

/// Test helper to construct [Publication] instances with deterministic UTC timestamps.
Publication createTestPublication({
  int? id,
  String? code,
  required String name,
  String? description,
  String? type,
  TriStateValue<String> size = const TriStateValue.sinDefinir(),
  TriStateValue<String> version = const TriStateValue.sinDefinir(),
  bool isActive = true,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final defaultTimestamp = DateTime.utc(2026, 8, 20, 10, 0);
  return Publication(
    id: id,
    code: code,
    name: name,
    description: description,
    type: type,
    size: size,
    version: version,
    isActive: isActive,
    createdAt: createdAt ?? defaultTimestamp,
    updatedAt: updatedAt ?? defaultTimestamp,
  );
}
