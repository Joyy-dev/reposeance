import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:reposeance/features/export/domain/models/export_result.dart';
import 'package:reposeance/features/export/domain/services/file_saver.dart';

/// Production implementation of [FileSaver] using native Windows file dialogs.
class WindowsFileSaver implements FileSaver {
  const WindowsFileSaver();

  @override
  Future<ExportResult> saveFile({
    required String fileName,
    required Uint8List bytes,
    String? dialogTitle,
    String? initialDirectory,
  }) async {
    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: dialogTitle ?? 'Save RepoSéance Forensic Autopsy Report',
        fileName: fileName,
        bytes: bytes,
        initialDirectory: initialDirectory,
      );

      if (uri == null) {
        return ExportResult.cancelled();
      }

      final resolvedPath = uri.isScheme('file') ? uri.toFilePath() : uri.path;
      return ExportResult.success(
        filePath: resolvedPath,
        fileUri: uri,
        bytesWritten: bytes.length,
      );
    } on FileSystemException catch (e) {
      debugPrint('WindowsFileSaver file system error: $e');
      return ExportResult.failed(
        'File system error: ${e.message}${e.path != null ? " (${e.path})" : ""}',
      );
    } catch (e) {
      debugPrint('WindowsFileSaver unexpected error: $e');
      return ExportResult.failed('Failed to save file: $e');
    }
  }
}
