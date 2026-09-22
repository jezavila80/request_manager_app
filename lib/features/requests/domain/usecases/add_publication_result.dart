import '../../../publications/domain/publication.dart';
import '../request.dart';
import '../request_item.dart';

/// Base class for the result of attempting to add a [Publication] to a [Request].
sealed class AddPublicationResult {
  const AddPublicationResult();
}

/// Result returned when a [Publication] was not present in the [Request]
/// and was successfully added as a new [RequestItem].
final class PublicationAddedToRequest extends AddPublicationResult {
  final Request request;
  final Publication publication;
  final RequestItem addedItem;

  const PublicationAddedToRequest({
    required this.request,
    required this.publication,
    required this.addedItem,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicationAddedToRequest &&
          runtimeType == other.runtimeType &&
          request == other.request &&
          publication == other.publication &&
          addedItem == other.addedItem;

  @override
  int get hashCode =>
      request.hashCode ^ publication.hashCode ^ addedItem.hashCode;

  @override
  String toString() =>
      'PublicationAddedToRequest(publication: ${publication.name}, requested: ${addedItem.quantityRequested})';
}

/// Result returned when a [Publication] is already present in the [Request].
///
/// Indicates to the presentation layer that user confirmation is needed
/// before accumulating quantity. The [currentRequest] remains unmodified.
final class PublicationAlreadyInRequest extends AddPublicationResult {
  final Request currentRequest;
  final Publication publication;
  final RequestItem existingItem;
  final int quantityToAdd;

  const PublicationAlreadyInRequest({
    required this.currentRequest,
    required this.publication,
    required this.existingItem,
    required this.quantityToAdd,
  });

  /// The resulting requested quantity if the user confirms the accumulation.
  int get newTotalQuantity => existingItem.quantityRequested + quantityToAdd;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicationAlreadyInRequest &&
          runtimeType == other.runtimeType &&
          currentRequest == other.currentRequest &&
          publication == other.publication &&
          existingItem == other.existingItem &&
          quantityToAdd == other.quantityToAdd;

  @override
  int get hashCode =>
      currentRequest.hashCode ^
      publication.hashCode ^
      existingItem.hashCode ^
      quantityToAdd.hashCode;

  @override
  String toString() =>
      'PublicationAlreadyInRequest(publication: ${publication.name}, current: ${existingItem.quantityRequested}, toAdd: $quantityToAdd, total: $newTotalQuantity)';
}
