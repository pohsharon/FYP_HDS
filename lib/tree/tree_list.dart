import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/tree/tree_details.dart';
import 'package:fyp_hbs/tree/create_tree.dart';

class TreePage extends StatelessWidget {
  const TreePage({super.key});

  @override
  Widget build(BuildContext context) {
    final mockTreeList = [
      {
        'id': 'M000001',
        'type': 'Musang King',
        'status': 'Flowering',
        'date': '4 Jan 2020',
      },
      {
        'id': 'M000002',
        'type': 'Musang King',
        'status': 'Fruiting',
        'date': '7 Jan 2020',
      },
      {
        'id': 'B000003',
        'type': 'Black Thorn',
        'status': 'Flowering',
        'date': '4 Jan 2020',
      },
      {
        'id': 'M000004',
        'type': 'Musang King',
        'status': 'Fruiting',
        'date': '9 Jan 2020',
      },
      {
        'id': 'B000005',
        'type': 'Black Thorn',
        'status': 'Fruiting',
        'date': '3 Jan 2020',
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
                itemCount: mockTreeList.length,
                itemBuilder: (context, index) {
                  final tree = mockTreeList[index];
                  return _buildTreeCard(
                    context,
                    id: tree['id']!,
                    type: tree['type']!,
                    status: tree['status']!,
                    date: tree['date']!,
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
          const Icon(Icons.location_on, color: AppColors.danger, size: 30),
          const SizedBox(width: 5),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search Tree ID',
                 hintStyle: TextStyle(
                  color: AppColors.gray600,
                  fontSize: 12,
                ),
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
                MaterialPageRoute(builder: (context) => CreateTreePage()),
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

  Widget _buildTreeCard(
    BuildContext context, {
    required String id,
    required String type,
    required String status,
    required String date,
  }) {
    Color statusColor =
        status == 'Flowering' ? AppColors.successLight : AppColors.dangerLight;
    Color statusTextColor =
        status == 'Flowering'
            ? AppColors.successActive
            : AppColors.dangerActive;

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
            // QR Code Icon (you can replace with actual QR image later)
            SizedBox(
              width: 50,
              height: 50,

              child: Image.asset('assets/images/QR.png', fit: BoxFit.contain),
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
                        id,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: statusTextColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        type,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "•",
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date,
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
                  MaterialPageRoute(
                    builder: (context) => TreeDetailsPage(treeId: id),
                  ),
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
