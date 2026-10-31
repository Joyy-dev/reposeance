import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/workbench/presentation/screens/workbench_screen.dart';

/// Root application widget for RepoSéance workbench.
class RepoSeanceApp extends StatelessWidget {
  const RepoSeanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RepoSéance — Repository Autopsy Workbench',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const WorkbenchScreen(),
    );
  }
}
