import 'dart:typed_data';

import 'package:reposeance/features/export/domain/models/export_result.dart';

/// Pluggable interface for persisting export bytes to the host filesystem.
abstract class FileSaver {
  /// Prompts the user or destination and saves [bytes] with default [fileName].
  ///
  /// Returns [ExportResult.success] when saved, [ExportResult.cancelled] when cancelled,
  /// or [ExportResult.failed] upon an unrecoverable I/O or platform error.
  Future<ExportResult> saveFile({
    required String fileName,
    required Uint8List bytes,
    String? dialogTitle,
    String? initialDirectory,
  });
}
