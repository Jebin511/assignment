import 'dart:math';

import 'package:assignment/screens/experience_selection/experience_selection_screen.dart';
import 'package:assignment/screens/onboarding_question/onboarding_question_screen.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  await Hive.openBox('host_data');
  runApp(const MyApp());

}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const ExperienceSelectionScreen(), // <-- pass your progress step here
    );
  }
}