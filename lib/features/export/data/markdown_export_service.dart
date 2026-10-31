import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_report.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
import 'package:reposeance/features/export/data/markdown_formatter.dart';
import 'package:reposeance/features/export/data/windows_file_saver.dart';
import 'package:reposeance/features/export/domain/models/export_options.dart';
import 'package:reposeance/features/export/domain/models/export_result.dart';
import 'package:reposeance/features/export/domain/services/file_saver.dart';
import 'package:reposeance/features/ghost_qa/domain/models/ghost_answer.dart';
import 'package:reposeance/features/ghost_qa/domain/models/ghost_question.dart';
import 'package:reposeance/features/repository/domain/models/repository_info.dart';
import 'package:reposeance/features/repository/domain/models/scan_result.dart';

/// Orchestrates generating Markdown reports and saving them to the host filesystem.
class MarkdownExportService {
  final MarkdownFormatter _formatter;
  final FileSaver _defaultSaver;

  MarkdownExportService({MarkdownFormatter? formatter, FileSaver? defaultSaver})
    : _formatter = formatter ?? const MarkdownFormatter(),
      _defaultSaver = defaultSaver ?? const WindowsFileSaver();

  /// Generates the Markdown autopsy report and saves it using [fileSaver].
  Future<ExportResult> exportReport({
    required AutopsyReport report,
    required EvidenceSnapshot snapshot,
    RepositoryInfo? repoInfo,
    ScanResult? scanResult,
    GhostQuestion? ghostQuestion,
    GhostAnswer? ghostAnswer,
    ExportOptions options = const ExportOptions(),
    FileSaver? fileSaver,
    DateTime? exportTimestamp,
  }) async {
    try {
      // 1. Generate formatted Markdown content
      final markdownString = _formatter.format(
        report: report,
        snapshot: snapshot,
        repoInfo: repoInfo,
        scanResult: scanResult,
        ghostQuestion: ghostQuestion,
        ghostAnswer: ghostAnswer,
        options: options,
        exportTimestamp: exportTimestamp,
      );

      // 2. Encode to UTF-8 bytes
      final bytes = Uint8List.fromList(utf8.encode(markdownString));

      // 3. Formulate default file name
      final defaultFileName = generateDefaultFileName(
        repoName: repoInfo?.name ?? 'repository',
        snapshotId: snapshot.snapshotId,
        timestamp: exportTimestamp ?? DateTime.now().toUtc(),
      );

      // 4. Save file via designated FileSaver
      final saver = fileSaver ?? _defaultSaver;
      final result = await saver.saveFile(
        fileName: defaultFileName,
        bytes: bytes,
        dialogTitle: 'Save RepoSéance Forensic Autopsy Report (.md)',
      );

      return result;
    } catch (e, stack) {
      debugPrint('MarkdownExportService error: $e\n$stack');
      return ExportResult.failed('Unexpected error during export: $e');
    }
  }

  /// Generates a clean, platform-safe default file name without illegal characters.
  static String generateDefaultFileName({
    required String repoName,
    required String snapshotId,
    required DateTime timestamp,
  }) {
    // Strip illegal filesystem characters: \ / : * ? " < > | and spaces
    var cleanName = repoName
        .replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    if (cleanName.endsWith('_')) {
      cleanName = cleanName.substring(0, cleanName.length - 1);
    }
    if (cleanName.startsWith('_')) {
      cleanName = cleanName.substring(1);
    }

    final dateStr =
        '${timestamp.year}${_twoDigits(timestamp.month)}${_twoDigits(timestamp.day)}';

    final idSuffix = snapshotId.length > 8
        ? snapshotId.substring(0, 8)
        : snapshotId;

    return '${cleanName}_autopsy_${dateStr}_$idSuffix.md';
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
}
