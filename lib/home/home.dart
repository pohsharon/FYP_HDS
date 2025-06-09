import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/home/user_management/user_list.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
        backgroundColor: AppColors.hunterGreen,
      ),
      body: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => UserListPage()),
          );
        },
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.gray600,
            shape: BoxShape.rectangle,
          ),
          padding: const EdgeInsets.all(6),
          child: const Icon(Icons.manage_accounts, color: Colors.white),
        ),
      ),
      backgroundColor: AppColors.background,
    );
  }
}
