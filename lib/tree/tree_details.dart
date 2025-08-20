import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/tree_api.dart';
import 'package:fyp_hbs/tree/health/heatlh_tab.dart';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fyp_hbs/tree/map_individual_tree.dart';
import 'package:fyp_hbs/tree/create_tree.dart';

class TreeDetailsPage extends StatefulWidget {
  final String treeID;

  const TreeDetailsPage({super.key, required this.treeID});

  @override
  State<TreeDetailsPage> createState() => _TreeDetailsPageState();
}

class _TreeDetailsPageState extends State<TreeDetailsPage> {
  bool isLoading = true;
  Map<String, dynamic>? tree;

  @override
  void initState() {
    super.initState();
    _loadTreeDetails();
  }

  Future<void> _loadTreeDetails() async {
    try {
      final data = await TreeApi.getTreeByUuid(widget.treeID);
      setState(() {
        tree = data;
        isLoading = false;
      });
    } catch (e1) {
      try {
        final data = await TreeApi.getTreeById(widget.treeID);
        setState(() {
          tree = data;
          isLoading = false;
        });
      } catch (e2) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading tree: $e2')));
      }
    }
  }

  Widget _buildTreeImage(String? thumbnail) {
    if (thumbnail != null && thumbnail.isNotEmpty) {
      try {
        // Remove prefix if it exists
        final base64Str =
            thumbnail.startsWith("data:image")
                ? thumbnail.split(',').last
                : thumbnail;

        return ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: Image.memory(
            base64Decode(base64Str),
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      } catch (e) {
        return _buildDefaultImage();
      }
    } else {
      return _buildDefaultImage();
    }
  }

  Widget _buildDefaultImage() {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.grey[200],
      child: const Center(
        child: Text('No image available', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (tree == null) {
      return const Scaffold(body: Center(child: Text("Failed to load tree.")));
    }

    final String treeTag = tree!['tree_tag'] ?? 'Unknown';
    final String treeType = tree!['species']?['name'] ?? 'Unknown Type';
    final String treeDate = tree!['planted_at'] ?? 'Unknown Date';
    final String treeImage = tree!['thumbnail'] ?? '';
    final String uuid = tree!['uuid'] ?? 'Unknown UUID';
    final String floweringPeriod = tree!['flowering_period']?.toString() ?? '-';
    final double height = double.tryParse(tree!['height'].toString()) ?? 0;
    final double width = double.tryParse(tree!['width'].toString()) ?? 0;
    final double latitude = double.tryParse(tree!['latitude'].toString()) ?? 0;
    final double longitude =
        double.tryParse(tree!['longitude'].toString()) ?? 0;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Tree Details",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: AppColors.pakistanGreen,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () async {
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CreateTreePage(tree: tree)),
                );

                if (updated == true) {
                  _loadTreeDetails();
                }
              },
            ),
          ],
        ),
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            GestureDetector(
              onTap: () {
                if (treeImage.isNotEmpty) {
                  showDialog(
                    context: context,
                    builder:
                        (_) => Dialog(
                          backgroundColor: Colors.white,
                          child: InteractiveViewer(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                base64Decode(treeImage.split(',').last),
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                        ),
                  );
                }
              },
              child: _buildTreeImage(treeImage),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder:
                            (_) => Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 100,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    QrImageView(
                                      data: uuid,
                                      version: QrVersions.auto,
                                      size: 300,
                                      gapless: true,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      uuid,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      );
                    },
                    child: QrImageView(
                      data: uuid,
                      version: QrVersions.auto,
                      size: 80,
                      gapless: true,
                    ),
                  ),

                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          treeTag,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          treeType,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.pin_drop,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Lat: ${latitude.toStringAsFixed(5)}, Lon: ${longitude.toStringAsFixed(5)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => MapIndividualTreePage(
                                treeLatitude: latitude,
                                treeLongitude: longitude,
                                treeTag: treeTag,
                                treeUuid: uuid,
                              ),
                        ),
                      );
                    },
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
                  _InfoCard(label: "Flowering Period", value: floweringPeriod),
                  _InfoCard(label: "Height", value: "$height m"),
                  _InfoCard(label: "Width", value: "$width m"),
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
            Expanded(
              child: TabBarView(
                children: [
                  HealthTabPage(treeTag: treeTag, treeUuid: uuid),
                  const _TabContent(title: "No fertilization records found."),
                  const _TabContent(title: "No pesticide records found."),
                  const _TabContent(title: "No harvest records found."),
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
