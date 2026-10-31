import 'dart:convert';
import 'dart:typed_data';

import 'package:reposeance/features/export/domain/models/export_result.dart';
import 'package:reposeance/features/export/domain/services/file_saver.dart';

/// In-memory implementation of [FileSaver] for deterministic unit testing.
class MemoryFileSaver implements FileSaver {
  bool shouldCancel;
  String? failureError;
  String? lastSavedFileName;
  Uint8List? lastSavedBytes;
  String? lastSavedContent;
  String? lastDialogTitle;
  String? lastInitialDirectory;

  MemoryFileSaver({this.shouldCancel = false, this.failureError});

  @override
  Future<ExportResult> saveFile({
    required String fileName,
    required Uint8List bytes,
    String? dialogTitle,
    String? initialDirectory,
  }) async {
    lastSavedFileName = fileName;
    lastSavedBytes = bytes;
    lastSavedContent = utf8.decode(bytes);
    lastDialogTitle = dialogTitle;
    lastInitialDirectory = initialDirectory;

    if (shouldCancel) {
      return ExportResult.cancelled();
    }

    if (failureError != null) {
      return ExportResult.failed(failureError!);
    }

    final simulatedPath = 'C:\\Exports\\$fileName';
    return ExportResult.success(
      filePath: simulatedPath,
      fileUri: Uri.file(simulatedPath),
      bytesWritten: bytes.length,
    );
  }
}
