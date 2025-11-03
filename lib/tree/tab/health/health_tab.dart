import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'create_health_info.dart';
import 'package:fyp_hbs/services/api/health_api.dart';
import 'disease_list.dart';
import 'package:fyp_hbs/config.dart'; // for building image URL

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
  int? _filterDiseaseId;
  String? _filterDiseaseName;

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

              final records = snapshot.data!;

              final filteredRecords = records.where((record) {
                final diseaseName = record['disease']?['diseaseName']?.toString().toLowerCase() ?? '';
                final matchesSearch = diseaseName.contains(searchQuery.toLowerCase());
                final matchesDiseaseFilter = _filterDiseaseId == null
                    ? true
                    : (record['disease']?['id'] == _filterDiseaseId);
                return matchesSearch && matchesDiseaseFilter;
              }).toList();

              if (filteredRecords.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No health records match your search or filter.')),
                );
              }

              return Column(
                children:
                    filteredRecords
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
        // List icon button
        IconButton(
          icon: const Icon(
            Icons.list_alt_rounded,
            color: AppColors.hunterGreen,
          ),
          tooltip: 'View Disease List',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) =>
                        const DiseaseListPage(), // <-- navigate to your DiseaseListPage
              ),
            );
          },
        ),
        const SizedBox(width: 8),

        // Search bar
        Expanded(
          child: TextField(
            onChanged: (value) => setState(() => searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search Disease',
              hintStyle: const TextStyle(
                color: AppColors.gray600,
                fontSize: 14,
              ),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: GestureDetector(
                onTap: () => _showDiseaseFilterDialog(),
                child: Icon(
                  Icons.filter_alt_outlined,
                  color: _filterDiseaseId == null ? null : AppColors.hunterGreen,
                ),
              ),
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

        // Add button
        ElevatedButton.icon(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => CreateHealthInfoPage(
                      treeTag: widget.treeTag,
                      treeUuid: widget.treeUuid,
                      existingRecord: null,
                    ),
              ),
            );
            if (result == true) setState(() {}); // refresh
          },
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.hunterGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTreeImage(String? thumbnail) {
    if (thumbnail != null && thumbnail.isNotEmpty) {
      final imageUrl =
          '${Config.supabaseBaseUrl}$thumbnail'; // ✅ Correct Supabase path

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultImage();
          },
        ),
      );
    } else {
      return _buildDefaultImage();
    }
  }

  Widget _buildDefaultImage() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
          SizedBox(height: 10),
          Text('No Image Available'),
        ],
      ),
    );
  }

  void _showImage(Map<String, dynamic> record) {
    final String? thumbnail =
        record['thumbnail']; // or record['diseaseImage'] if named differently

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: _buildTreeImage(
              thumbnail,
            ), // ✅ Use same function as Tree Details
          ),
        );
      },
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

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => CreateHealthInfoPage(
                  treeTag: widget.treeTag,
                  treeUuid: widget.treeUuid,
                  existingRecord: record,
                ),
          ),
        );
        if (result == true) setState(() {});
      },
      child: Card(
        color: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 1,
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Disease name + treatment
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record['disease']['diseaseName'],
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        if ((record['treatment'] ?? "").isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            record['treatment'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.gray700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Date + Status chips
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (recordedAt.isNotEmpty)
                        Text(
                          recordedAt,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.gray600,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Bottom: view image (aligned right)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.photo_library_outlined),
                  onPressed: () => _showImage(record),
                  tooltip: 'View Image',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDiseaseFilterDialog() async {
    try {
      final List<Map<String, dynamic>> diseases = await HealthApi.fetchDiseases();

      String? tempSelectedName = _filterDiseaseName;
      int? tempSelectedId = _filterDiseaseId;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Filter by Disease'),
            content: StatefulBuilder(
              builder: (context, setStateDialog) {
                return SizedBox(
                  width: double.maxFinite,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: tempSelectedId,
                    hint: const Text('Select a disease'),
                    items: (() {
                      final List<DropdownMenuItem<int>> list = [];
                      for (final d in diseases) {
                        final idValue = d['id'];
                        final int? id = idValue is int
                            ? idValue
                            : (idValue != null ? int.tryParse(idValue.toString()) : null);
                        final name = (d['diseaseName'] ?? d['name'] ?? '').toString();
                        if (id != null) {
                          list.add(DropdownMenuItem<int>(value: id, child: Text(name)));
                        }
                      }
                      return list;
                    })(),
                    onChanged: (v) {
                      setStateDialog(() {
                        tempSelectedId = v;
                        final Map<String, dynamic> sel = diseases.firstWhere(
                          (x) => (x['id'] == v),
                          orElse: () => <String, dynamic>{},
                        );
                        tempSelectedName = (sel['diseaseName'] ?? sel['name'] ?? '').toString();
                      });
                    },
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // clear filter
                  setState(() {
                    _filterDiseaseId = null;
                    _filterDiseaseName = null;
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('Clear'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _filterDiseaseId = tempSelectedId;
                    _filterDiseaseName = tempSelectedName;
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      // show simple dialog on error
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to load diseases: $e'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
          ],
        ),
      );
    }
  }
}
