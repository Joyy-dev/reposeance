import 'package:reposeance/features/autopsy/domain/models/autopsy_finding.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_report.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_item.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
import 'package:reposeance/features/export/domain/models/export_options.dart';
import 'package:reposeance/features/ghost_qa/domain/models/ghost_answer.dart';
import 'package:reposeance/features/ghost_qa/domain/models/ghost_question.dart';
import 'package:reposeance/features/repository/domain/models/repository_info.dart';
import 'package:reposeance/features/repository/domain/models/scan_result.dart';

/// Pure Dart deterministic Markdown serializer for RepoSéance autopsy reports.
///
/// Produces clean, portable, privacy-preserving GitHub-flavored Markdown.
/// Strictly scrubs personal user home directories, API tokens, and raw model prompts.
class MarkdownFormatter {
  const MarkdownFormatter();

  /// Serializes the investigation report, metadata, and optional Q&A into Markdown.
  String format({
    required AutopsyReport report,
    required EvidenceSnapshot snapshot,
    RepositoryInfo? repoInfo,
    ScanResult? scanResult,
    GhostQuestion? ghostQuestion,
    GhostAnswer? ghostAnswer,
    ExportOptions options = const ExportOptions(),
    DateTime? exportTimestamp,
  }) {
    final buffer = StringBuffer();
    final timestamp = exportTimestamp ?? DateTime.now().toUtc();
    final repoName =
        repoInfo?.name ??
        scanResult?.repositoryInfo.name ??
        'Unknown Repository';
    final repoRoot =
        repoInfo?.rootPath ??
        scanResult?.repositoryInfo.rootPath ??
        snapshot.repositoryRoot;

    // 1. Header & Title
    final title = options.customTitle ?? 'RepoSéance Forensic Autopsy Report';
    buffer.writeln('# $title: ${sanitizePath(repoName, repoRoot)}');
    buffer.writeln();
    buffer.writeln(
      '> **Notice**: Forensic archaeological analysis generated locally using local '
      'open-weight AI (`gemma4:e2b`). Repository files and commit metadata are treated '
      'as untrusted historical evidence. All findings cite immutable snapshot evidence records.',
    );
    buffer.writeln();

    // 2. Metadata Table
    buffer.writeln('## Forensic Investigation Metadata');
    buffer.writeln();
    buffer.writeln('| Metadata Property | Value |');
    buffer.writeln('|:---|:---|');
    buffer.writeln(
      '| **Target Repository** | `${escapeTable(sanitizePath(repoName, repoRoot))}` |',
    );
    buffer.writeln(
      '| **Active Branch** | `${escapeTable(repoInfo?.currentBranch ?? scanResult?.repositoryInfo.currentBranch ?? "HEAD")}` |',
    );
    buffer.writeln(
      '| **HEAD Commit** | `${escapeTable(repoInfo?.headCommitHash ?? scanResult?.repositoryInfo.headCommitHash ?? snapshot.headCommit ?? "unknown")}` |',
    );
    buffer.writeln(
      '| **Snapshot ID** | `${escapeTable(snapshot.snapshotId)}` |',
    );
    buffer.writeln(
      '| **Local AI Engine** | `gemma4:e2b (Ollama loopback 127.0.0.1:11434, CPU)` |',
    );
    buffer.writeln(
      '| **Analysis Timestamp** | `${timestamp.toIso8601String()}` |',
    );

    final selectedCount =
        scanResult?.files.length ?? snapshot.fileEvidence.length;
    final totalBytes = scanResult?.totalBytesRead ?? 0;
    final commitCount =
        scanResult?.commits.length ?? snapshot.commitEvidence.length;
    buffer.writeln(
      '| **Inspected Scope** | $selectedCount tracked files (${_formatBytes(totalBytes)}) · $commitCount commits |',
    );

    if (scanResult != null) {
      buffer.writeln(
        '| **Enumerated Candidates** | ${scanResult.totalCandidatesEnumerated} paths evaluated (${scanResult.scanDurationMs}ms scan) |',
      );
    }
    buffer.writeln();

    // 3. Partial Scan Limitations Warning
    final isPartial = scanResult?.isPartial ?? false;
    final partialReasons = scanResult?.partialWarnings ?? [];
    if (isPartial || partialReasons.isNotEmpty) {
      buffer.writeln('> [!WARNING]');
      buffer.writeln('> **Partial Inspection Scope Disclosures**:');
      for (final reason in partialReasons) {
        buffer.writeln('> - ${escapeMarkdown(sanitizeText(reason, repoRoot))}');
      }
      buffer.writeln(
        '>\n> *Note: Excluded, uninspected, or oversized files may alter the archaeological conclusions.*',
      );
      buffer.writeln();
    }

    // 4. Project Purpose
    if (report.projectPurpose != null) {
      buffer.writeln('## 1. Project Purpose');
      buffer.writeln();
      final purposeKind = report.projectPurpose!.kind == FindingKind.observed
          ? '**[Observed]**'
          : '**[Inferred]**';
      final purposeCitations = _formatCitations(
        report.projectPurpose!.evidenceIds,
      );
      buffer.writeln(
        '$purposeKind ${sanitizeText(report.projectPurpose!.text, repoRoot)}$purposeCitations',
      );
      buffer.writeln();
    }

    // 5. Architecture Overview
    buffer.writeln('## 2. Architecture Overview');
    buffer.writeln();
    if (report.architecture.isEmpty) {
      buffer.writeln('_No major architecture components identified._');
    } else {
      for (var i = 0; i < report.architecture.length; i++) {
        final finding = report.architecture[i];
        final kind = finding.kind == FindingKind.observed
            ? '**[Observed]**'
            : '**[Inferred]**';
        final citations = _formatCitations(finding.evidenceIds);
        buffer.writeln(
          '${i + 1}. $kind ${sanitizeText(finding.text, repoRoot)}$citations',
        );
      }
    }
    buffer.writeln();

    // 6. What the Evidence Says (Findings)
    buffer.writeln('## 3. What the Evidence Says');
    buffer.writeln();
    if (report.findings.isEmpty) {
      buffer.writeln('_No factual repository findings recorded._');
    } else {
      for (var i = 0; i < report.findings.length; i++) {
        final finding = report.findings[i];
        final kind = finding.kind == FindingKind.observed
            ? '**[Observed]**'
            : '**[Inferred]**';
        final citations = _formatCitations(finding.evidenceIds);
        buffer.writeln(
          '- $kind ${sanitizeText(finding.text, repoRoot)}$citations',
        );
      }
    }
    buffer.writeln();

    // 7. Commit Timeline Table
    final commits = scanResult?.commits ?? [];
    if (commits.isNotEmpty) {
      buffer.writeln('## 4. Inspected Recent Commit Timeline');
      buffer.writeln();
      buffer.writeln('| Short SHA | Date (UTC) | Author | Commit Subject |');
      buffer.writeln('|:---|:---|:---|:---|');
      for (final commit in commits) {
        final shortSha = commit.shortHash.isNotEmpty
            ? commit.shortHash
            : commit.hash.substring(0, 7);
        final dateStr = commit.date.toIso8601String().split('T').first;
        final author = sanitizeText(commit.author, repoRoot);
        final subject = sanitizeText(commit.subject, repoRoot);
        buffer.writeln(
          '| `${escapeTable(shortSha)}` | $dateStr | `${escapeTable(author)}` | ${escapeTable(subject)} |',
        );
      }
      buffer.writeln();
    }

    // 8. Recommended Revival Plan
    buffer.writeln('## 5. Recommended Revival Plan');
    buffer.writeln();
    if (report.revivalPlan.isEmpty) {
      buffer.writeln('_No revival steps recommended._');
    } else {
      for (var i = 0; i < report.revivalPlan.length; i++) {
        final step = report.revivalPlan[i];
        final reasonKind = step.reason.kind == FindingKind.observed
            ? '**[Observed]**'
            : '**[Inferred]**';
        final citations = _formatCitations(step.reason.evidenceIds);
        buffer.writeln(
          '### Step ${i + 1}: ${sanitizeText(step.step, repoRoot)}',
        );
        buffer.writeln(
          '- **Grounded Reason**: $reasonKind ${sanitizeText(step.reason.text, repoRoot)}$citations',
        );
        buffer.writeln();
      }
    }
    buffer.writeln(
      '> *Disclaimer: RepoSéance is a passive forensic tool. Recommended next steps are never executed automatically.*',
    );
    buffer.writeln();

    // 9. Forensic Unknowns & Limitations
    buffer.writeln('## 6. Forensic Unknowns & Limitations');
    buffer.writeln();
    if (report.unknowns.isEmpty) {
      buffer.writeln('_No explicit unknowns declared._');
    } else {
      for (final unknown in report.unknowns) {
        buffer.writeln('- ${sanitizeText(unknown, repoRoot)}');
      }
    }
    buffer.writeln();

    // 10. Optional Ask the Ghost Q&A Inquiries
    if (options.includeGhostQa &&
        ghostQuestion != null &&
        ghostAnswer != null) {
      buffer.writeln('## 7. Ask the Ghost Q&A Inquiries');
      buffer.writeln();
      buffer.writeln(
        '**Question**: "${sanitizeText(ghostQuestion.text, repoRoot)}"',
      );
      buffer.writeln(
        '**Inquiry Timestamp**: ${ghostQuestion.askedAt.toIso8601String()}',
      );
      buffer.writeln();

      if (ghostAnswer.notFound) {
        buffer.writeln('> [!NOTE]');
        buffer.writeln(
          '> **Epistemic Classification: Not Found / Missing Evidence**',
        );
        buffer.writeln(
          '> ${sanitizeText(ghostAnswer.missingEvidence ?? "No specific explanation supplied.", repoRoot)}',
        );
      } else {
        buffer.writeln('### Grounded Findings:');
        for (final claim in ghostAnswer.claims) {
          final kind = claim.kind == FindingKind.observed
              ? '**[Observed]**'
              : '**[Inferred]**';
          final citations = _formatCitations(claim.evidenceIds);
          buffer.writeln(
            '- $kind: ${sanitizeText(claim.text, repoRoot)}$citations',
          );
        }
      }
      buffer.writeln();
    }

    // 11. Evidence Ledger & Provenance Map
    buffer.writeln('## 8. Evidence Ledger & Provenance Map');
    buffer.writeln();
    buffer.writeln(
      'This ledger maps all evidence citation IDs referenced in this report directly to immutable snapshot source records.',
    );
    buffer.writeln();

    final citedIds = _collectCitedEvidenceIds(
      report: report,
      ghostAnswer: options.includeGhostQa ? ghostAnswer : null,
    );

    if (citedIds.isEmpty) {
      buffer.writeln('_No evidence items cited in report._');
    } else {
      for (final id in citedIds) {
        final item = snapshot.getEvidence(id);
        if (item == null) {
          buffer.writeln('### Evidence Item `[$id]`');
          buffer.writeln('_Unresolved or omitted evidence ID._');
          buffer.writeln();
          continue;
        }

        if (item is FileEvidence) {
          buffer.writeln(
            '### Evidence Item `[$id]` — `${escapeMarkdown(sanitizePath(item.repositoryRelativePath, repoRoot))}`',
          );
          buffer.writeln(
            '- **Source File**: `${escapeMarkdown(sanitizePath(item.repositoryRelativePath, repoRoot))}` (Lines ${item.startLine}–${item.endLine})',
          );
          buffer.writeln('- **SHA-256 Provenance**: `${item.contentHash}`');
          buffer.writeln('- **Captured Excerpt**:');
          buffer.writeln('```');
          buffer.writeln(sanitizeCredentials(item.content));
          buffer.writeln('```');
        } else if (item is CommitEvidence) {
          final shortHash = item.commitHash.length >= 7
              ? item.commitHash.substring(0, 7)
              : item.commitHash;
          buffer.writeln('### Evidence Item `[$id]` — Commit `$shortHash`');
          buffer.writeln('- **Commit Hash**: `${item.commitHash}`');
          if (item.author != null) {
            buffer.writeln(
              '- **Author**: `${escapeMarkdown(sanitizeText(item.author!, repoRoot))}`',
            );
          }
          buffer.writeln('- **Commit Date**: `${item.date.toIso8601String()}`');
          buffer.writeln(
            '- **Subject**: ${escapeMarkdown(sanitizeText(item.subject, repoRoot))}',
          );
        }
        buffer.writeln();
      }
    }

    buffer.writeln('---');
    buffer.writeln(
      '*Report compiled deterministically by RepoSéance. Zero repository scripts or builds executed.*',
    );

    return buffer.toString();
  }

  // --- Sanitization & Privacy Guards ---

  /// Sanitizes text by redacting personal user profile paths and credentials.
  static String sanitizeText(String text, [String? repoRoot]) {
    var result = text;
    result = sanitizePath(result, repoRoot);
    result = sanitizeCredentials(result);
    return result;
  }

  /// Scrubs personal Windows user profile directories and absolute repository paths.
  static String sanitizePath(String text, [String? repoRoot]) {
    var result = text;

    // 1. Scrub absolute repository root if provided
    if (repoRoot != null && repoRoot.isNotEmpty) {
      final normalizedRoot = repoRoot.replaceAll('\\', '/');
      result = result.replaceAll(repoRoot, '<repo-root>');
      result = result.replaceAll(normalizedRoot, '<repo-root>');
    }

    // 2. Scrub Windows User directories: e.g. C:\Users\<username>\ or C:/Users/<username>/
    final userProfileRegex = RegExp(
      r'[a-zA-Z]:[\\/][Uu]sers[\\/][^\\/]+[\\/]',
      caseSensitive: false,
    );
    result = result.replaceAll(userProfileRegex, '<user-home>/');

    // 3. Scrub Unix/Mac User directories: e.g. /home/<user>/ or /Users/<user>/
    final unixProfileRegex = RegExp(r'/(home|[Uu]sers)/[^/]+/');
    result = result.replaceAll(unixProfileRegex, '<user-home>/');

    return result;
  }

  /// Scrubs secret-like patterns, tokens, and private keys.
  static String sanitizeCredentials(String text) {
    var result = text;

    // Bearer / Token / Secret assignments
    final tokenRegex = RegExp(
      r'\b(bearer|token|apikey|api_key|secret|password|access_token)\s*[:=\s]\s*["'
      ']?[A-Za-z0-9_.-]{8,}["'
      ']?',
      caseSensitive: false,
    );
    result = result.replaceAllMapped(tokenRegex, (m) {
      final key = m.group(1);
      return '$key: [REDACTED_SECRET]';
    });

    // GitHub PAT tokens
    final githubPatRegex = RegExp(r'\bgh[pousr]_[A-Za-z0-9_]{20,}\b');
    result = result.replaceAll(githubPatRegex, 'ghp_[REDACTED]');

    // Private key blocks
    final privateKeyRegex = RegExp(
      r'-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----',
    );
    result = result.replaceAll(privateKeyRegex, '[REDACTED_PRIVATE_KEY]');

    return result;
  }

  /// Escapes pipe characters so strings can be safely placed in Markdown tables.
  static String escapeTable(String text) {
    return text.replaceAll('|', r'\|').replaceAll('\n', ' ');
  }

  /// Escapes Markdown structural characters where needed.
  static String escapeMarkdown(String text) {
    return text.replaceAll('\r', '');
  }

  // --- Helper Methods ---

  static String _formatCitations(List<String> evidenceIds) {
    if (evidenceIds.isEmpty) return '';
    final sorted = List<String>.from(evidenceIds)..sort();
    return ' [${sorted.map((id) => id).join(', ')}]';
  }

  static List<String> _collectCitedEvidenceIds({
    required AutopsyReport report,
    GhostAnswer? ghostAnswer,
  }) {
    final ids = <String>{};
    if (report.projectPurpose != null) {
      ids.addAll(report.projectPurpose!.evidenceIds);
    }
    for (final f in report.architecture) {
      ids.addAll(f.evidenceIds);
    }
    for (final f in report.findings) {
      ids.addAll(f.evidenceIds);
    }
    for (final s in report.revivalPlan) {
      ids.addAll(s.reason.evidenceIds);
    }
    if (ghostAnswer != null) {
      for (final claim in ghostAnswer.claims) {
        ids.addAll(claim.evidenceIds);
      }
    }
    final sorted = ids.toList()..sort();
    return sorted;
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
  }
}
