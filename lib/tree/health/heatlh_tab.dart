import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'create_health_info.dart';

class HealthTabPage extends StatefulWidget {
  final String treeTag;
  final String treeUuid;
  const HealthTabPage({
    super.key,
    required this.treeTag,
    required this.treeUuid,
  });

  @override
  State<HealthTabPage> createState() => _HealthTabPageState();
}

class _HealthTabPageState extends State<HealthTabPage> {
  final List<String> diseases = ['Disease A', 'Disease B', 'Disease C'];
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredDiseases =
        diseases
            .where((d) => d.toLowerCase().contains(searchQuery.toLowerCase()))
            .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(width: 5),
              Expanded(
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search Disease',
                    hintStyle: TextStyle(
                      color: AppColors.gray600,
                      fontSize: 12,
                    ),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: GestureDetector(
                      onTap:
                          () => setState(() {
                            searchQuery = '';
                          }),
                      child: const Icon(Icons.filter_alt_outlined),
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(
                        color: AppColors.gray400,
                        width: 1.2,
                      ),
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
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => CreateHealthInfoPage(
                            treeTag: widget.treeTag,
                            treeUuid: widget.treeUuid,
                          ),
                    ),
                  );

                  if (result == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Disease list updated')),
                    );
                  }
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
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: filteredDiseases.length,
              itemBuilder: (context, index) {
                final disease = filteredDiseases[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.gray300),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      disease,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Navigate to disease details
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
