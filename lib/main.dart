import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const SnailDefenseApp());
}

class SnailDefenseApp extends StatelessWidget {
  const SnailDefenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snail Defense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

