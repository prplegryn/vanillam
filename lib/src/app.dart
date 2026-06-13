import 'package:flutter/material.dart';

import 'ui/workbench_page.dart';

class VanillaApp extends StatelessWidget {
  const VanillaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1F5EFF);

    return MaterialApp(
      title: 'vanilla',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          primary: seed,
          surface: const Color(0xFFF7FAFF),
          error: const Color(0xFFC62828),
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F6FC),
        visualDensity: VisualDensity.standard,
        tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 350)),
      ),
      home: const WorkbenchPage(),
    );
  }
}
