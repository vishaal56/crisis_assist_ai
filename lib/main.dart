import 'package:flutter/material.dart';
import 'auth/login_screen.dart';

void main() => runApp(const CrisisAssistApp());

class CrisisAssistApp extends StatelessWidget {
  const CrisisAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CrisisAssist AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginScreen(),
    );
  }
}

class AppTheme {
  static ThemeData? get light => null;
}