import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';

class TreeDetailsPage extends StatelessWidget {
  final Map<String, dynamic> tree;

  const TreeDetailsPage({super.key, required this.tree});

  @override
  Widget build(BuildContext context) {
    final String treeTag = tree['tree_tag'] ?? 'Unknown';
    final String treeType = tree['species']?['name'] ?? 'Unknown Type';
    final String treeDate = tree['planted_at'] ?? 'Unknown Date';
    final String treeUuid = tree['uuid'] ?? '';
    final String treeImage = tree['thumbnail_base64'] ?? '';
    final String treeStatus = tree['status'] ?? 'Unknown Status';
    final int height = tree['height'] ?? 0;
    final int width = tree['width'] ?? 0;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            Container(
              height: 60,
              color: Colors.white,
              alignment: Alignment.centerLeft,
            ),
            Stack(
              children: [
                Image.asset(
                  'assets/images/durianImage.jpeg',
                  width: double.infinity,
                  height: 280,
                  fit: BoxFit.fitWidth,
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(blurRadius: 4, color: Colors.black26),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              // TODO: navigate to edit tree page
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset("assets/images/QR.png", width: 50),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              treeTag,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Add status label here if needed
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          treeType,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.lightGreen,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.pakistanGreen,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _InfoCard(label: "Planting Date", value: treeDate),
                  _InfoCard(
                    label: "Flowering Period",
                    value: tree['flowering_period']?.toString() ?? '-',
                  ),
                  _InfoCard(
                    label: "Height",
                    value: tree['height'] != null ? "${tree['height']} m" : '-',
                  ),
                  _InfoCard(
                    label: "Width",
                    value: tree['width'] != null ? "${tree['width']} m" : '-',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const TabBar(
              labelColor: AppColors.hunterGreen,
              unselectedLabelColor: AppColors.hunterGreen,
              tabs: [
                Tab(text: "Health"),
                Tab(text: "Fertilization"),
                Tab(text: "Pesticide"),
                Tab(text: "Harvest"),
              ],
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              unselectedLabelStyle: TextStyle(fontSize: 11),
              indicatorColor: AppColors.hunterGreen,
              indicatorWeight: 3,
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _TabContent(title: "No health records found."),
                  _TabContent(title: "No fertilization records found."),
                  _TabContent(title: "No pesticide records found."),
                  _TabContent(title: "No harvest records found."),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;

  const _InfoCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.42,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray400, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  final String title;

  const _TabContent({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(title, style: const TextStyle(color: Colors.grey)),
    );
  }
}
