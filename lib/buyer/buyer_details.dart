import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';

class BuyerDetailsPage extends StatelessWidget {
  const BuyerDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Buyer Details"),
        backgroundColor: AppColors.hunterGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Company: Durian Lovers",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text("PIC: John Doe"),
            const Text("Phone: +60123456789"),
            const Text("Email: john.doe@example.com"),
            const Text("Location: Kuala Lumpur"),
            const Text("State: Kedah"),
          ],
        ),
      ),
    );
  }
}