class AutopsyException implements Exception {
  final String message;
  const AutopsyException(this.message);

  @override
  String toString() => message;
}

class AutopsyValidationException extends AutopsyException {
  final List<String> errors;
  final String? rawResponse;
  final int repairAttempts;

  AutopsyValidationException(
    super.message, {
    this.errors = const [],
    this.rawResponse,
    this.repairAttempts = 0,
  });

  @override
  String toString() =>
      '$message\nValidation errors:\n - ${errors.join('\n - ')}';
}

class AutopsyTimeoutException extends AutopsyException {
  final Duration timeout;
  AutopsyTimeoutException(super.message, this.timeout);
}

class AutopsyUnavailableException extends AutopsyException {
  AutopsyUnavailableException(super.message);
}

class AutopsyCancelledException extends AutopsyException {
  AutopsyCancelledException([
    super.message = 'Autopsy generation cancelled by user.',
  ]);
}
