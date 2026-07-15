import 'package:flutter/material.dart';

class TestAppWidget extends StatelessWidget {
  const TestAppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(backgroundColor: Colors.blueAccent),
    );
  }
}
