import '../../../../core/time/app_date_time.dart';
import 'services/requester_name_cleaner.dart';
import 'services/requester_name_normalizer.dart';

class Requester {
  final int? id;
  final String name;
  final String normalizedName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Requester._({
    this.id,
    required this.name,
    required this.normalizedName,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory constructor to validate and construct a [Requester].
  ///
  /// Invariants:
  /// - [id] if provided must be > 0.
  /// - [name] must contain at least two significant words after cleaning whitespace.
  /// - [normalizedName] is automatically computed using [RequesterNameNormalizer].
  /// - [createdAt] and [updatedAt] are normalized to UTC.
  /// - [updatedAt] cannot be earlier than [createdAt].
  factory Requester({
    int? id,
    required String name,
    String? normalizedName,
    bool isActive = true,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    if (id != null && id <= 0) {
      throw ArgumentError('El ID del solicitante debe ser mayor a cero.');
    }

    final cleanedName = RequesterNameCleaner.clean(name);
    if (!RequesterNameCleaner.hasAtLeastTwoSignificantWords(cleanedName)) {
      throw ArgumentError(
        'El nombre del solicitante debe contener al menos dos palabras significativas.',
      );
    }

    final effectiveNormalized =
        normalizedName ?? RequesterNameNormalizer.normalize(cleanedName);

    if (effectiveNormalized.isEmpty) {
      throw ArgumentError(
        'El nombre normalizado del solicitante no puede estar vacío.',
      );
    }

    final effectiveCreatedAt = AppDateTime.normalizeUtc(createdAt);
    final effectiveUpdatedAt = AppDateTime.normalizeUtc(updatedAt);

    if (effectiveUpdatedAt.isBefore(effectiveCreatedAt)) {
      throw ArgumentError(
        'La fecha de actualización (updatedAt) no puede ser anterior a la fecha de creación (createdAt).',
      );
    }

    return Requester._(
      id: id,
      name: cleanedName,
      normalizedName: effectiveNormalized,
      isActive: isActive,
      createdAt: effectiveCreatedAt,
      updatedAt: effectiveUpdatedAt,
    );
  }

  Requester copyWith({
    int? id,
    String? name,
    String? normalizedName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Requester(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName:
          normalizedName ?? (name != null ? null : this.normalizedName),
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Requester &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          normalizedName == other.normalizedName &&
          isActive == other.isActive &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      normalizedName.hashCode ^
      isActive.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() =>
      'Requester(id: $id, name: "$name", normalized: "$normalizedName", active: $isActive)';
}
