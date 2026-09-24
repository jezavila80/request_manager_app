import '../../../../core/time/app_clock.dart';
import '../../../publications/domain/publication.dart';
import '../request.dart';
import '../request_exceptions.dart';
import '../request_item.dart';
import 'add_publication_result.dart';

export 'add_publication_result.dart';

/// Use case that manages adding existing [Publication]s to an in-memory [Request]
/// and accumulating quantities upon user confirmation.
class AddPublicationToRequestUseCase {
  final AppClock _clock;

  const AddPublicationToRequestUseCase({
    required AppClock clock,
  }) : _clock = clock;

  /// Creates a new in-memory [Request] with timestamps generated deterministically
  /// from [_clock.nowUtc()].
  ///
  /// Guarantees that `createdAt == updatedAt` and both are UTC.
  Request createRequest({
    required int requesterId,
    String? notes,
    List<RequestItem> items = const [],
  }) {
    final now = _clock.nowUtc();
    return Request(
      requesterId: requesterId,
      notes: notes,
      items: items,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Attempts to add an existing [publication] with [quantity] to [request].
  ///
  /// - If [publication] is not yet in [request], creates a new [RequestItem] with
  ///   `quantityFulfilled = 0` and adds it to the request with an updated timestamp,
  ///   returning [PublicationAddedToRequest].
  /// - If [publication] is already in [request], does NOT modify the request and
  ///   returns [PublicationAlreadyInRequest] so the UI can prompt the user for confirmation.
  ///
  /// Throws [ArgumentError] if [publication.id] is null or <= 0.
  /// Throws [ArgumentError] if [quantity] is <= 0.
  AddPublicationResult addPublication({
    required Request request,
    required Publication publication,
    required int quantity,
  }) {
    if (publication.id == null || publication.id! <= 0) {
      throw ArgumentError(
        'La publicación debe estar persistida y tener un ID válido mayor a cero.',
      );
    }
    if (quantity <= 0) {
      throw ArgumentError(
        'La cantidad solicitada debe ser un entero positivo mayor a cero.',
      );
    }

    final pubId = publication.id!;
    final existingIndex =
        request.items.indexWhere((item) => item.publicationId == pubId);

    if (existingIndex != -1) {
      return PublicationAlreadyInRequest(
        currentRequest: request,
        publication: publication,
        existingItem: request.items[existingIndex],
        quantityToAdd: quantity,
      );
    }

    final newItem = RequestItem(
      publicationId: pubId,
      quantityRequested: quantity,
      quantityFulfilled: 0,
    );

    final now = _clock.nowUtc();
    final updatedRequest = request.addItem(newItem, updatedAt: now);

    return PublicationAddedToRequest(
      request: updatedRequest,
      publication: publication,
      addedItem: newItem,
    );
  }

  /// Accumulates [quantityToAdd] onto the existing [RequestItem] for [publicationId]
  /// in [request] after the user confirms the action.
  ///
  /// - Keeps a single [RequestItem] for that publication with `newQuantity = current + quantityToAdd`.
  /// - Preserves `quantityFulfilled`.
  /// - Updates `updatedAt` using [_clock.nowUtc()].
  ///
  /// Throws [ArgumentError] if [publicationId] is <= 0.
  /// Throws [ArgumentError] if [quantityToAdd] is <= 0.
  /// Throws [RequestItemNotFoundException] if [publicationId] is not in [request].
  Request confirmAccumulation({
    required Request request,
    required int publicationId,
    required int quantityToAdd,
  }) {
    if (publicationId <= 0) {
      throw ArgumentError(
        'El ID de la publicación debe ser mayor a cero.',
      );
    }
    if (quantityToAdd <= 0) {
      throw ArgumentError(
        'La cantidad a acumular debe ser un entero positivo mayor a cero.',
      );
    }

    final existingItem = request.items.firstWhere(
      (item) => item.publicationId == publicationId,
      orElse: () => throw RequestItemNotFoundException(publicationId),
    );

    final newQuantity = existingItem.quantityRequested + quantityToAdd;
    final now = _clock.nowUtc();

    return request.updateItemQuantityRequested(
      publicationId,
      newQuantity,
      updatedAt: now,
    );
  }

  /// Convenience method to confirm accumulation using a [Publication] instance.
  Request confirmAccumulationForPublication({
    required Request request,
    required Publication publication,
    required int quantityToAdd,
  }) {
    if (publication.id == null || publication.id! <= 0) {
      throw ArgumentError(
        'La publicación debe estar persistida y tener un ID válido mayor a cero.',
      );
    }
    return confirmAccumulation(
      request: request,
      publicationId: publication.id!,
      quantityToAdd: quantityToAdd,
    );
  }
}
