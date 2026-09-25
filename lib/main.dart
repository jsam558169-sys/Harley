import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const HarleyPosApp());
}

class HarleyPosApp extends StatelessWidget {
  const HarleyPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Harley's Inventory and Sales System",
      theme: AppTheme.themeData,
      home: const LoginScreen(),
    );
  }
}
