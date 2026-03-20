import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:QUIK/config/firebase_options.dart';
import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/auth/auth_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const QuikApp());
}

class QuikApp extends StatelessWidget {
  const QuikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: buildQuikTheme(),
      home: const AuthWrapper(),
    );
  }
}