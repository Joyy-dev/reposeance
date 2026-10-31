import 'dart:async';
import 'dart:io';

/// Result of checking Git availability on host machine.
class GitCheckResult {
  final bool isInstalled;
  final String? version;
  final String? error;

  const GitCheckResult({required this.isInstalled, this.version, this.error});

  const GitCheckResult.notInstalled([this.error])
    : isInstalled = false,
      version = null;

  const GitCheckResult.installed(this.version)
    : isInstalled = true,
      error = null;
}

/// Utility for safely checking Git toolchain on Windows host without shell interpolation.
class GitChecker {
  GitChecker._();

  static Future<GitCheckResult> checkGit({
    Duration timeout = const Duration(milliseconds: 2000),
  }) async {
    try {
      final result = await Process.run('git', [
        '--version',
      ], runInShell: false).timeout(timeout);

      if (result.exitCode == 0) {
        final versionString = (result.stdout as String).trim();
        return GitCheckResult.installed(versionString);
      } else {
        return GitCheckResult.notInstalled(
          'Git check exited with code ${result.exitCode}: ${result.stderr}',
        );
      }
    } on TimeoutException {
      return const GitCheckResult.notInstalled('Git process check timed out');
    } on ProcessException catch (e) {
      return GitCheckResult.notInstalled(
        'Git executable not found: ${e.message}',
      );
    } catch (e) {
      return GitCheckResult.notInstalled(e.toString());
    }
  }
}
