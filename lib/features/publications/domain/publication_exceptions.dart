abstract class PublicationException implements Exception {
  final String message;
  final dynamic cause;

  PublicationException(this.message, [this.cause]);

  @override
  String toString() =>
      '$runtimeType: $message${cause != null ? " (Causa: $cause)" : ""}';
}

class PublicationPersistenceException extends PublicationException {
  PublicationPersistenceException(super.message, [super.cause]);
}

class DuplicatePublicationCodeException
    extends PublicationPersistenceException {
  final String code;

  DuplicatePublicationCodeException(this.code, [dynamic cause])
      : super(
            'Ya existe una publicación registrada con el código: $code', cause);
}

class PublicationAlreadyPersistedException extends PublicationException {
  final int id;

  PublicationAlreadyPersistedException(this.id)
      : super(
            'La publicación ya ha sido persistida con el ID: $id. No se puede crear de nuevo.');
}
