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
