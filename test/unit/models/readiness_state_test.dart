import 'package:flutter_test/flutter_test.dart';
import 'package:reposeance/core/services/ollama_service.dart';
import 'package:reposeance/core/utils/git_checker.dart';
import 'package:reposeance/features/readiness/models/readiness_state.dart';

void main() {
  group('SystemReadinessState Unit Tests', () {
    test('initial state has checking true and not ready', () {
      final initial = SystemReadinessState.initial();
      expect(initial.isChecking, isTrue);
      expect(initial.isGitReady, isFalse);
      expect(initial.isOllamaReady, isFalse);
      expect(initial.isSystemReady, isFalse);
      expect(initial.hasDirectorySelected, isFalse);
      expect(initial.canProceedToScan, isFalse);
    });

    test('isSystemReady requires both Git and Ollama ready', () {
      const gitReady = GitCheckResult.installed('git version 2.56.0');
      const gitMissing = GitCheckResult.notInstalled('not found');
      const ollamaReady = OllamaHealthResult(status: OllamaHealthStatus.ready);
      const ollamaMissing = OllamaHealthResult(
        status: OllamaHealthStatus.runningModelMissing,
      );

      final bothReady = SystemReadinessState(
        isChecking: false,
        gitResult: gitReady,
        ollamaResult: ollamaReady,
      );
      expect(bothReady.isSystemReady, isTrue);

      final gitOnly = SystemReadinessState(
        isChecking: false,
        gitResult: gitReady,
        ollamaResult: ollamaMissing,
      );
      expect(gitOnly.isSystemReady, isFalse);

      final ollamaOnly = SystemReadinessState(
        isChecking: false,
        gitResult: gitMissing,
        ollamaResult: ollamaReady,
      );
      expect(ollamaOnly.isSystemReady, isFalse);
    });

    test('canProceedToScan requires system ready and directory selected', () {
      final state = SystemReadinessState(
        isChecking: false,
        gitResult: const GitCheckResult.installed('git version 2.56.0'),
        ollamaResult: const OllamaHealthResult(
          status: OllamaHealthStatus.ready,
        ),
        selectedDirectory: r'C:\Users\tester\projects\demo_repo',
      );
      expect(state.canProceedToScan, isTrue);
      expect(state.hasDirectorySelected, isTrue);

      final stateNoDir = state.copyWith(clearDirectory: true);
      expect(stateNoDir.canProceedToScan, isFalse);
      expect(stateNoDir.hasDirectorySelected, isFalse);
    });

    test(
      'copyWith updates fields correctly and clearDirectory resets path',
      () {
        final state = SystemReadinessState.initial();
        final updated = state.copyWith(
          isChecking: false,
          selectedDirectory: r'D:\code\target',
        );
        expect(updated.isChecking, isFalse);
        expect(updated.selectedDirectory, equals(r'D:\code\target'));

        final cleared = updated.copyWith(clearDirectory: true);
        expect(cleared.selectedDirectory, isNull);
      },
    );
  });
}
