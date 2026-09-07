class RequestItem {
  final int? id;
  final int publicationId;
  final int quantityRequested;
  final int quantityFulfilled;

  // Private constructor to enforce validation in factory constructors
  const RequestItem._({
    this.id,
    required this.publicationId,
    required this.quantityRequested,
    required this.quantityFulfilled,
  });

  /// Factory constructor to create and validate a [RequestItem].
  ///
  /// Invariants:
  /// - [publicationId] must be > 0.
  /// - [quantityRequested] must be > 0.
  /// - [quantityFulfilled] must be >= 0 and <= [quantityRequested].
  factory RequestItem({
    int? id,
    required int publicationId,
    required int quantityRequested,
    int quantityFulfilled = 0,
  }) {
    if (id != null && id <= 0) {
      throw ArgumentError('El ID del renglón debe ser mayor a cero.');
    }
    if (publicationId <= 0) {
      throw ArgumentError('El ID de la publicación debe ser mayor a cero.');
    }
    if (quantityRequested <= 0) {
      throw ArgumentError(
          'La cantidad solicitada debe ser un entero positivo mayor a cero.');
    }
    if (quantityFulfilled < 0) {
      throw ArgumentError(
          'La cantidad surtida no puede ser un número negativo.');
    }
    if (quantityFulfilled > quantityRequested) {
      throw ArgumentError(
          'La cantidad surtida ($quantityFulfilled) no puede exceder la cantidad solicitada ($quantityRequested).');
    }

    return RequestItem._(
      id: id,
      publicationId: publicationId,
      quantityRequested: quantityRequested,
      quantityFulfilled: quantityFulfilled,
    );
  }

  /// Returns a new [RequestItem] with updated publicationId, preserving id,
  /// quantityRequested, and quantityFulfilled.
  RequestItem replacePublication(int newPublicationId) {
    return copyWith(publicationId: newPublicationId);
  }

  /// Returns a new [RequestItem] with an updated quantityRequested, validating invariants.
  RequestItem withQuantityRequested(int newQuantityRequested) {
    return copyWith(quantityRequested: newQuantityRequested);
  }

  /// Returns a new [RequestItem] with an updated quantityFulfilled, validating invariants.
  RequestItem withQuantityFulfilled(int newQuantityFulfilled) {
    return copyWith(quantityFulfilled: newQuantityFulfilled);
  }

  /// Returns a new [RequestItem] preserving unspecified fields.
  RequestItem copyWith({
    int? id,
    int? publicationId,
    int? quantityRequested,
    int? quantityFulfilled,
  }) {
    return RequestItem(
      id: id ?? this.id,
      publicationId: publicationId ?? this.publicationId,
      quantityRequested: quantityRequested ?? this.quantityRequested,
      quantityFulfilled: quantityFulfilled ?? this.quantityFulfilled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          publicationId == other.publicationId &&
          quantityRequested == other.quantityRequested &&
          quantityFulfilled == other.quantityFulfilled;

  @override
  int get hashCode =>
      id.hashCode ^
      publicationId.hashCode ^
      quantityRequested.hashCode ^
      quantityFulfilled.hashCode;

  @override
  String toString() =>
      'RequestItem(id: $id, publicationId: $publicationId, requested: $quantityRequested, fulfilled: $quantityFulfilled)';
}
