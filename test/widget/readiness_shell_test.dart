import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:reposeance/app.dart';
import 'package:reposeance/core/services/ollama_service.dart';
import 'package:reposeance/core/utils/git_checker.dart';
import 'package:reposeance/features/readiness/controllers/readiness_controller.dart';
import 'package:reposeance/features/readiness/models/readiness_state.dart';

void main() {
  testWidgets(
    'ReadinessScreen renders header, directory selector, and diagnostics',
    (tester) async {
      // Configure desktop testing viewport (1280x800)
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Provide a mocked OllamaService
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/version') {
          return http.Response(jsonEncode({'version': '0.40.13'}), 200);
        } else if (request.url.path == '/api/tags') {
          return http.Response(
            jsonEncode({
              'models': [
                {'name': 'gemma4:e2b'},
              ],
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final mockOllama = OllamaService(
        baseUri: 'http://127.0.0.1:11434',
        targetModel: 'gemma4:e2b',
        client: mockClient,
      );

      final controller = ReadinessController(
        ollamaService: mockOllama,
        gitChecker: () async =>
            const GitCheckResult.installed('git version 2.56.0'),
        autoCheck: false,
        initialState: const SystemReadinessState(
          isChecking: false,
          gitResult: GitCheckResult.installed('git version 2.56.0'),
          ollamaResult: OllamaHealthResult(
            status: OllamaHealthStatus.ready,
            version: '0.40.13',
            models: ['gemma4:e2b'],
          ),
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ReadinessController>.value(
          value: controller,
          child: const RepoSeanceApp(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Brand
      expect(find.text('RepoSéance'), findsOneWidget);
      expect(find.text('v1.0 (M2)'), findsOneWidget);

      // Verify Hero title
      expect(
        find.text('Automated Local Repository Autopsy Workbench'),
        findsOneWidget,
      );

      // Verify Directory Selector Card
      expect(find.text('Target Repository for Autopsy'), findsOneWidget);
      expect(find.text('Select Repository Folder'), findsOneWidget);

      // Verify Host Environment Diagnostics Card
      expect(find.text('Host Environment Diagnostics'), findsOneWidget);
      expect(find.text('Git Binary'), findsOneWidget);
      expect(find.text('Ollama Service'), findsOneWidget);
      expect(find.text('Local Model'), findsOneWidget);

      // Verify Milestone Notice
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    },
  );
}
