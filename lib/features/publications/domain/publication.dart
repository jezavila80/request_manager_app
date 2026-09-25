import '../../../../core/time/app_date_time.dart';
import 'publication_status.dart';
import 'tri_state_value.dart';

class Publication {
  final int? id;
  final String? code;
  final String name;
  final String? description;
  final String? type;
  final TriStateValue<String> size;
  final TriStateValue<String> version;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Private constructor to enforce validation in factories
  Publication._({
    this.id,
    this.code,
    required this.name,
    this.description,
    this.type,
    required this.size,
    required this.version,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory constructor to create and validate a standard Publication.
  /// Trims text fields and maps empty strings to null (except name which throws an error).
  ///
  /// Timestamps [createdAt] and [updatedAt] are required and normalized to UTC.
  factory Publication({
    int? id,
    String? code,
    required String name,
    String? description,
    String? type,
    TriStateValue<String> size = const TriStateValue.sinDefinir(),
    TriStateValue<String> version = const TriStateValue.sinDefinir(),
    bool isActive = true,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError(
          'El nombre de la publicación no puede estar vacío o contener únicamente espacios.');
    }

    final normalizedCode =
        (code == null || code.trim().isEmpty) ? null : code.trim();
    final normalizedType =
        (type == null || type.trim().isEmpty) ? null : type.trim();
    final normalizedDescription =
        (description == null || description.trim().isEmpty)
            ? null
            : description.trim();

    final effectiveCreatedAt = AppDateTime.normalizeUtc(createdAt);
    final effectiveUpdatedAt = AppDateTime.normalizeUtc(updatedAt);

    return Publication._(
      id: id,
      code: normalizedCode,
      name: trimmedName,
      description: normalizedDescription,
      type: normalizedType,
      size: size,
      version: version,
      isActive: isActive,
      createdAt: effectiveCreatedAt,
      updatedAt: effectiveUpdatedAt,
    );
  }

  /// Factory constructor specifically for quick drafts created from requests.
  /// Sets [code] to null (ensuring status is [PublicationStatus.draft]).
  /// [name] is required and must not be blank.
  /// [description] is optional; empty or whitespace-only descriptions are normalized to null.
  /// [type], [size], and [version] are optional with their standard defaults.
  ///
  /// Timestamps [createdAt] and [updatedAt] are required and normalized to UTC.
  factory Publication.quickDraft({
    required String name,
    String? description,
    String? type,
    TriStateValue<String> size = const TriStateValue.sinDefinir(),
    TriStateValue<String> version = const TriStateValue.sinDefinir(),
    int? id,
    bool isActive = true,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return Publication(
      id: id,
      code: null,
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

  /// Exposes the publication status dynamically calculated from its fields.
  PublicationStatus get status {
    final hasCode = code != null && code!.trim().isNotEmpty;
    final hasName = name.trim().isNotEmpty;
    final hasType = type != null && type!.trim().isNotEmpty;

    return (hasCode && hasName && hasType)
        ? PublicationStatus.complete
        : PublicationStatus.draft;
  }

  /// Returns a new Publication with the updated fields, preserving other values.
  /// Uses functions for nullable parameters to allow explicitly setting them to null.
  /// Preserves [createdAt] and [updatedAt] unless explicitly specified.
  Publication copyWith({
    int? id,
    String? Function()? code,
    String? name,
    String? Function()? description,
    String? Function()? type,
    TriStateValue<String>? size,
    TriStateValue<String>? version,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Publication(
      id: id ?? this.id,
      code: code != null ? code() : this.code,
      name: name ?? this.name,
      description: description != null ? description() : this.description,
      type: type != null ? type() : this.type,
      size: size ?? this.size,
      version: version ?? this.version,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Publication &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          name == other.name &&
          description == other.description &&
          type == other.type &&
          size == other.size &&
          version == other.version &&
          isActive == other.isActive &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      code.hashCode ^
      name.hashCode ^
      description.hashCode ^
      type.hashCode ^
      size.hashCode ^
      version.hashCode ^
      isActive.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() {
    return 'Publication(id: $id, code: $code, name: $name, status: $status, size: $size, version: $version, isActive: $isActive)';
  }
}
