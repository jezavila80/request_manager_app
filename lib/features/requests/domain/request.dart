import 'dart:collection';

import '../../../../core/time/app_date_time.dart';
import '../../publications/domain/publication.dart';
import '../../publications/domain/publication_status.dart';
import 'request_exceptions.dart';
import 'request_fulfillment_status.dart';
import 'request_item.dart';

class Request {
  final int? id;
  final String requestedBy;
  final List<RequestItem> _items;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Private constructor to enforce validation in factory constructor
  Request._({
    this.id,
    required this.requestedBy,
    required List<RequestItem> items,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  }) : _items = items;

  /// Factory constructor to create and validate a [Request].
  ///
  /// Invariants:
  /// - [requestedBy] cannot be empty or contain only whitespace.
  /// - [items] cannot contain duplicate [publicationId] references.
  /// - [updatedAt] cannot be earlier than [createdAt].
  ///
  /// Timestamps [createdAt] and [updatedAt] are required and normalized to UTC.
  factory Request({
    int? id,
    required String requestedBy,
    List<RequestItem> items = const [],
    String? notes,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    if (id != null && id <= 0) {
      throw ArgumentError('El ID del pedido debe ser mayor a cero.');
    }

    final trimmedRequestedBy = requestedBy.trim();
    if (trimmedRequestedBy.isEmpty) {
      throw ArgumentError(
          'El solicitante del pedido no puede estar vacío o contener únicamente espacios.');
    }

    // Check duplicate publicationIds in initial items
    final seenPublicationIds = <int>{};
    for (final item in items) {
      if (!seenPublicationIds.add(item.publicationId)) {
        throw DuplicatePublicationInRequestException(item.publicationId);
      }
    }

    final normalizedNotes =
        (notes == null || notes.trim().isEmpty) ? null : notes.trim();

    final effectiveCreatedAt = AppDateTime.normalizeUtc(createdAt);
    final effectiveUpdatedAt = AppDateTime.normalizeUtc(updatedAt);

    if (effectiveUpdatedAt.isBefore(effectiveCreatedAt)) {
      throw ArgumentError(
          'La fecha de actualización (updatedAt) no puede ser anterior a la fecha de creación (createdAt).');
    }

    return Request._(
      id: id,
      requestedBy: trimmedRequestedBy,
      items: List.unmodifiable(items),
      notes: normalizedNotes,
      createdAt: effectiveCreatedAt,
      updatedAt: effectiveUpdatedAt,
    );
  }

  /// Unmodifiable view of the items in this request to prevent direct external mutation.
  List<RequestItem> get items => UnmodifiableListView(_items);

  /// Calculated total quantity of publications requested across all items.
  int get totalQuantityRequested =>
      _items.fold(0, (sum, item) => sum + item.quantityRequested);

  /// Calculated total quantity of publications fulfilled across all items.
  int get totalQuantityFulfilled =>
      _items.fold(0, (sum, item) => sum + item.quantityFulfilled);

  /// Indicates whether the request contains at least one item to be considered a valid order.
  bool get isValidForOrder => _items.isNotEmpty;

  /// Calculates the current fulfillment status of the request based on item quantities.
  ///
  /// Decision for empty requests: returns [RequestFulfillmentStatus.pending] as a default baseline.
  RequestFulfillmentStatus get fulfillmentStatus {
    if (_items.isEmpty) {
      return RequestFulfillmentStatus.pending;
    }

    final allFulfilled = _items
        .every((item) => item.quantityFulfilled == item.quantityRequested);
    if (allFulfilled) {
      return RequestFulfillmentStatus.fulfilled;
    }

    final allPending = _items.every((item) => item.quantityFulfilled == 0);
    if (allPending) {
      return RequestFulfillmentStatus.pending;
    }

    return RequestFulfillmentStatus.partiallyFulfilled;
  }

  /// Evaluates whether all items in this request refer to existing [Publication]s with
  /// status [PublicationStatus.complete].
  ///
  /// Pure domain method: does not perform DB or Repository operations.
  /// Returns `false` if any item's publication is missing from [publications],
  /// is a `DRAFT`, or if the request has no items.
  bool isFullyDefined(Iterable<Publication> publications) {
    if (_items.isEmpty) {
      return false;
    }

    final pubMap = {
      for (final pub in publications)
        if (pub.id != null) pub.id!: pub
    };

    for (final item in _items) {
      final pub = pubMap[item.publicationId];
      if (pub == null || pub.status != PublicationStatus.complete) {
        return false;
      }
    }

    return true;
  }

  /// Adds a new [RequestItem] to the request.
  ///
  /// Rejects addition if an item with the same [publicationId] already exists in the request.
  Request addItem(RequestItem item, {required DateTime updatedAt}) {
    if (_items
        .any((existing) => existing.publicationId == item.publicationId)) {
      throw DuplicatePublicationInRequestException(item.publicationId);
    }

    final newItems = List<RequestItem>.from(_items)..add(item);
    return copyWith(
      items: newItems,
      updatedAt: AppDateTime.normalizeUtc(updatedAt),
    );
  }

  /// Removes an item from the request by its [publicationId].
  ///
  /// Throws [RequestItemNotFoundException] if no item with the given [publicationId] exists.
  Request removeItem(int publicationId, {required DateTime updatedAt}) {
    final index =
        _items.indexWhere((item) => item.publicationId == publicationId);
    if (index == -1) {
      throw RequestItemNotFoundException(publicationId);
    }

    final newItems = List<RequestItem>.from(_items)..removeAt(index);
    return copyWith(
      items: newItems,
      updatedAt: AppDateTime.normalizeUtc(updatedAt),
    );
  }

  /// Replaces the publication reference of an existing item ([oldPublicationId] -> [newPublicationId]).
  ///
  /// Preserves the item's identity (`id`), `quantityRequested`, and `quantityFulfilled`.
  /// Throws [RequestItemNotFoundException] if [oldPublicationId] is not found.
  /// Throws [DuplicatePublicationInRequestException] if another item already uses [newPublicationId].
  Request replaceItemPublication({
    required int oldPublicationId,
    required int newPublicationId,
    required DateTime updatedAt,
  }) {
    final index =
        _items.indexWhere((item) => item.publicationId == oldPublicationId);
    if (index == -1) {
      throw RequestItemNotFoundException(oldPublicationId);
    }

    if (oldPublicationId == newPublicationId) {
      return this;
    }

    // Check if newPublicationId collides with any OTHER item in the request
    final collision = _items.any(
      (item) => item.publicationId == newPublicationId,
    );
    if (collision) {
      throw DuplicatePublicationInRequestException(newPublicationId);
    }

    final updatedItem = _items[index].replacePublication(newPublicationId);
    final newItems = List<RequestItem>.from(_items);
    newItems[index] = updatedItem;

    return copyWith(
      items: newItems,
      updatedAt: AppDateTime.normalizeUtc(updatedAt),
    );
  }

  /// Updates the requested quantity for an item identified by [publicationId].
  Request updateItemQuantityRequested(
    int publicationId,
    int newQuantityRequested, {
    required DateTime updatedAt,
  }) {
    final index =
        _items.indexWhere((item) => item.publicationId == publicationId);
    if (index == -1) {
      throw RequestItemNotFoundException(publicationId);
    }

    final updatedItem =
        _items[index].withQuantityRequested(newQuantityRequested);
    final newItems = List<RequestItem>.from(_items);
    newItems[index] = updatedItem;

    return copyWith(
      items: newItems,
      updatedAt: AppDateTime.normalizeUtc(updatedAt),
    );
  }

  /// Updates the fulfilled quantity for an item identified by [publicationId].
  Request updateItemQuantityFulfilled(
    int publicationId,
    int newQuantityFulfilled, {
    required DateTime updatedAt,
  }) {
    final index =
        _items.indexWhere((item) => item.publicationId == publicationId);
    if (index == -1) {
      throw RequestItemNotFoundException(publicationId);
    }

    final updatedItem =
        _items[index].withQuantityFulfilled(newQuantityFulfilled);
    final newItems = List<RequestItem>.from(_items);
    newItems[index] = updatedItem;

    return copyWith(
      items: newItems,
      updatedAt: AppDateTime.normalizeUtc(updatedAt),
    );
  }

  /// Creates a copy of this [Request] with updated fields.
  /// Preserves [createdAt] and [updatedAt] unless explicitly specified.
  Request copyWith({
    int? id,
    String? requestedBy,
    List<RequestItem>? items,
    String? Function()? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Request(
      id: id ?? this.id,
      requestedBy: requestedBy ?? this.requestedBy,
      items: items ?? _items,
      notes: notes != null ? notes() : this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Request &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          requestedBy == other.requestedBy &&
          notes == other.notes &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          _listEquals(_items, other._items);

  @override
  int get hashCode =>
      id.hashCode ^
      requestedBy.hashCode ^
      notes.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      Object.hashAll(_items);

  static bool _listEquals(List<RequestItem> a, List<RequestItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'Request(id: $id, requestedBy: "$requestedBy", items: ${_items.length}, status: $fulfillmentStatus, notes: $notes)';
}
