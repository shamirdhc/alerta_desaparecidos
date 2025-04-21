// lib/common/failure.dart

abstract class Failure {
  final String message;

  const Failure(this.message);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

// Puedes añadir otras clases de Failure aquí
