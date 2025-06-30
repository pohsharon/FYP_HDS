import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.pakistanGreen,
      ),
      body: Center(
        child: Text(
          'Settings Page',
          style: TextStyle(color: AppColors.black, fontSize: 24),
        ),
      ),
    );
  }
}