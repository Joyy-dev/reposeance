/// Base exception for Ghost Q&A operations.
abstract class GhostQaException implements Exception {
  final String message;
  const GhostQaException(this.message);

  @override
  String toString() => message;
}

/// Thrown when local Ollama service is unreachable, offline, or returns HTTP non-200.
class GhostQaServiceException extends GhostQaException {
  const GhostQaServiceException(super.message);
}

/// Thrown when model response fails JSON Schema or evidence allowlist validation after repair.
class GhostQaValidationException extends GhostQaException {
  final List<String> errors;

  GhostQaValidationException(this.errors)
    : super(
        'Ghost Q&A response validation failed:\n${errors.map((e) => '- $e').join('\n')}',
      );
}

/// Thrown when inference request exceeds the configured timeout.
class GhostQaTimeoutException extends GhostQaException {
  final Duration timeout;

  GhostQaTimeoutException(this.timeout)
    : super('Ghost Q&A request timed out after ${timeout.inSeconds} seconds.');
}

/// Thrown when user cancels an in-flight Q&A request.
class GhostQaCancelledException extends GhostQaException {
  const GhostQaCancelledException()
    : super('Ghost Q&A request was cancelled by the user.');
}
