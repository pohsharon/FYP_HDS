import 'package:flutter/material.dart';
import 'package:fyp_hbs/nav.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Hosba Durian System",
      home: Nav()
    );
  }
}
