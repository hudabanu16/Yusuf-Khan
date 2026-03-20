import 'package:flutter/material.dart';

class ScreenIotMonitoring extends StatelessWidget {
  const ScreenIotMonitoring({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          'IoT Monitoring Module',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}