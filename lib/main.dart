import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'features/readiness/controllers/readiness_controller.dart';
import 'features/workbench/controllers/workbench_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ReadinessController()),
        ChangeNotifierProvider(create: (_) => WorkbenchController()),
      ],
      child: const RepoSeanceApp(),
    ),
  );
}
