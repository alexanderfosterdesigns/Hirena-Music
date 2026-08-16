import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/logging.dart';
import 'design/theme.dart';
import 'state/providers.dart';
import 'ui/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HLog.init();
  runApp(const ProviderScope(child: HirenaApp()));
}

final class HirenaApp extends StatelessWidget {
  const HirenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hirena Music',
      debugShowCheckedModeBanner: false,
      theme: HTheme.dark(),
      home: const AppShell(),
    );
  }
}
