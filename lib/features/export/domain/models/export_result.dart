/// Status classification of an export operation.
enum ExportStatus {
  /// File was saved successfully to disk.
  success,

  /// User cancelled the file picker dialog; state remains unchanged.
  cancelled,

  /// File saving failed due to an I/O or platform error.
  failed,
}

/// Immutable result of an export operation.
class ExportResult {
  final ExportStatus status;
  final String? filePath;
  final Uri? fileUri;
  final String? errorMessage;
  final int bytesWritten;

  const ExportResult({
    required this.status,
    this.filePath,
    this.fileUri,
    this.errorMessage,
    this.bytesWritten = 0,
  });

  bool get isSuccess => status == ExportStatus.success;
  bool get isCancelled => status == ExportStatus.cancelled;
  bool get isFailed => status == ExportStatus.failed;

  factory ExportResult.success({
    required String filePath,
    Uri? fileUri,
    required int bytesWritten,
  }) {
    return ExportResult(
      status: ExportStatus.success,
      filePath: filePath,
      fileUri: fileUri ?? Uri.file(filePath),
      bytesWritten: bytesWritten,
    );
  }

  factory ExportResult.cancelled() {
    return const ExportResult(status: ExportStatus.cancelled);
  }

  factory ExportResult.failed(String errorMessage) {
    return ExportResult(
      status: ExportStatus.failed,
      errorMessage: errorMessage,
    );
  }
}
