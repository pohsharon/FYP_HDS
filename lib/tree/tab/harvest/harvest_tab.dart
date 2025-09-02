import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/tree_api.dart';
import 'fruit_list.dart';

class HarvestTabPage extends StatelessWidget {
  final String treeUuid;
  const HarvestTabPage({super.key, required this.treeUuid});

  Future<List<Map<String, dynamic>>> fetchHarvests() async {
    final response = await TreeApi.getHarvestsByTreeId(treeUuid);
    return response;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchHarvests(), // Replace with your API call
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final harvests = snapshot.data ?? [];
        if (harvests.isEmpty) {
          return const Center(child: Text('No harvest events found.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          itemCount: harvests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final harvest = harvests[index];
            return Card(
              // color: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.gray300),
              ),
              
              elevation: 0,
              child: ListTile(
                title: Text(
                  harvest['event_name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.hunterGreen),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FruitListPage(treeUuid: treeUuid),
                    ),
                  );
                                },
              ),
            );
          },
        );
      },
    );
  }
}