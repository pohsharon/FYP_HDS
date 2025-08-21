import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'create_health_info.dart';
import 'package:fyp_hbs/services/health_api.dart';

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
  String searchQuery = '';

@override
Widget build(BuildContext context) {
  return SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildSearchAndAddButton(),
        const SizedBox(height: 16),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: HealthApi.fetchHealthRecords(widget.treeUuid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("No health records found."));
            }

            final filteredRecords = snapshot.data!
                .where((record) => record['disease']['diseaseName']
                    .toString()
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()))
                .toList();

            return Column(
              children: filteredRecords
                  .map((record) => _buildRecordCard(record))
                  .toList(),
            );
          },
        ),
      ],
    ),
  );
}

  Widget _buildSearchAndAddButton() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (value) => setState(() => searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search Disease',
              hintStyle: TextStyle(
                    color: AppColors.gray600,
                    fontSize: 14,
                  ),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: GestureDetector(
                onTap: () => setState(() => searchQuery = ''),
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
        ElevatedButton.icon(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateHealthInfoPage(
                  treeTag: widget.treeTag,
                  treeUuid: widget.treeUuid,
                ),
              ),
            );
            if (result == true) setState(() {}); // refresh
          },
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
  // Format date if needed
  String recordedAt = record['recorded_at'] ?? "";
  String status = record['status'] ?? "";

  // Status color logic
  Color statusColor;
  switch (status) {
    case "Recovered":
      statusColor = AppColors.success;
      break;
    case "Severe":
      statusColor = AppColors.danger;
      break;
    case "Medium":
      statusColor = AppColors.warning;
      break;
    default:
      statusColor = AppColors.gray600;
  }

  return Card(
    color: AppColors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Disease name
              Text(
                record['disease']['diseaseName'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              // Date chip (right after disease name)
              if (recordedAt.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gray200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    recordedAt,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.infoActive,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const Spacer(),
              // Status chip (on the far right)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if ((record['treatment'] ?? "").isNotEmpty)
            Text(
              record['treatment'],
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.gray700,
              ),
            ),
        ],
      ),
    ),
  );
}

}
