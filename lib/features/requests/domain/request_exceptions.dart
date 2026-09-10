/// Base exception for request domain errors.
abstract class RequestException implements Exception {
  final String message;
  final dynamic cause;

  RequestException(this.message, [this.cause]);

  @override
  String toString() =>
      '$runtimeType: $message${cause != null ? " (Causa: $cause)" : ""}';
}

/// Thrown when attempting to add or replace a publication that is already
/// present in the request.
class DuplicatePublicationInRequestException extends RequestException {
  final int publicationId;

  DuplicatePublicationInRequestException(this.publicationId, [dynamic cause])
      : super(
          'El pedido ya contiene un renglón para la publicación con ID $publicationId.',
          cause,
        );
}

/// Thrown when attempting to perform an invalid item operation (e.g. item not found).
class RequestItemNotFoundException extends RequestException {
  final int publicationId;

  RequestItemNotFoundException(this.publicationId, [dynamic cause])
      : super(
          'No se encontró ningún renglón en el pedido para la publicación con ID $publicationId.',
          cause,
        );
}

/// Thrown when SQLite/persistence operation fails.
class RequestPersistenceException extends RequestException {
  RequestPersistenceException(super.message, [super.cause]);
}

/// Thrown when a Request is invalid for creation (e.g. empty items).
class InvalidRequestForCreationException extends RequestException {
  InvalidRequestForCreationException(super.message, [super.cause]);
}

/// Thrown when attempting to create a Request that already has an ID.
class RequestAlreadyPersistedException extends RequestException {
  final int id;

  RequestAlreadyPersistedException(this.id)
      : super(
            'La solicitud ya ha sido persistida con el ID: $id. No se puede crear de nuevo.');
}

/// Thrown when attempting to create a Request with an item that already has an ID.
class RequestItemAlreadyPersistedException extends RequestException {
  final int itemId;

  RequestItemAlreadyPersistedException(this.itemId)
      : super(
            'El ítem de la solicitud ya contiene un ID de persistencia: $itemId. No se puede crear como nuevo.');
}
