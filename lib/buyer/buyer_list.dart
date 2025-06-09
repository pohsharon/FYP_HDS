import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/buyer/create_buyer.dart';
import 'package:fyp_hbs/buyer/buyer_details.dart';

class BuyerPage extends StatelessWidget {
  const BuyerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mockBuyerData = [
      {
        'id': 'CMP00001',
        'company': 'Durian Lovers',
        'pic': 'John Doe',
        'phone': '+60123456789',
        'email': 'john.doe@example.com',
        'location': 'Kuala Lumpur',
        'state': 'Kedah',
      },
      {
        'id': 'CMP00002',
        'company': 'Fruit Paradise',
        'pic': 'Jane Smith',
        'phone': '+60198765432',
        'email': 'jane.smith@example.com',
        'location': 'George Town',
        'state': 'Penang',
      },
      {
        'id': 'CMP00003',
        'company': 'Tropical Fruits Co.',
        'pic': 'Alice Johnson',
        'phone': '+60123456789',
        'email': 'alice.johnson@example.com',
        'location': 'Ipoh',
        'state': 'Perak',
      },
      {
        'id': 'CMP00004',
        'company': 'Exotic Fruits Ltd.',
        'pic': 'Bob Brown',
        'phone': '+60123456789',
        'email': 'bob@gmail.com',
        'location': 'Kota Kinabalu',
        'state': 'Sabah',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildSearchBar(context),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: mockBuyerData.length,
                itemBuilder: (context, index) {
                  final buyer = mockBuyerData[index];
                  return _buildBuyerCard(
                    context,
                    id: buyer['id']!,
                    company: buyer['company']!,
                    pic: buyer['pic']!,
                    phone: buyer['phone']!,
                    email: buyer['email']!,
                    location: buyer['location']!,
                    state: buyer['state']!,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_long_rounded,
            color: AppColors.successActive,
            size: 30,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search Company Name',
                hintStyle: TextStyle(color: AppColors.gray600, fontSize: 12),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: const Icon(Icons.filter_alt_outlined),
                filled: true,
                fillColor: AppColors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: AppColors.gray400, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                    color: AppColors.hunterGreen,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CreateBuyerPage()),
              );
            },
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.pakistanGreen,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerCard(
    BuildContext context, {
    required String id,
    required String company,
    required String pic,
    required String phone,
    required String email,
    required String location,
    required String state,
  }) {
    return Card(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.gray400),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: ClipOval(
                child: Image.asset(
                  'assets/images/buyer.jpeg',
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(width: 12),
            // Tree info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        company,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        location,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        ",",
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        state,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(),
            // View Button
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BuyerDetailsPage()),
                );
              },

              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.hunterGreen,
                side: const BorderSide(color: AppColors.hunterGreen),
                minimumSize: const Size(60, 30), // Smaller height
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text("View"),
            ),
          ],
        ),
      ),
    );
  }
}
