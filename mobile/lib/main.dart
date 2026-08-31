import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const HabitQApp());
}

class HabitQApp extends StatelessWidget {
  const HabitQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HabitQ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.login,
      routes: AppRoutes.table,
    );
  }
}
