import 'package:flutter/material.dart';
import 'package:fyp_hbs/config.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/agrochemical_api.dart';
import 'package:fyp_hbs/tree/tab/agrochemical/create_agrochemical.dart';
import 'package:fyp_hbs/utils/connectivity_helper.dart';
import 'package:fyp_hbs/services/local database/agro_db.dart';
import 'package:fyp_hbs/models/agrochemical_model.dart';

class AgrochemicalTabPage extends StatefulWidget {
  final String treeUuid;
  const AgrochemicalTabPage({super.key, required this.treeUuid});

  @override
  State<AgrochemicalTabPage> createState() => _AgrochemicalTabPageState();
}

class _AgrochemicalTabPageState extends State<AgrochemicalTabPage> {
  String searchQuery = '';
  int? selectedIndex;

  Future<List<Map<String, dynamic>>> fetchAgrochemical() async {
    // Prefer remote when online, but fall back to local DB when offline or when API fails
    try {
      final online = await ConnectivityHelper.hasInternetConnection();
      if (online) {
        final response = await AgrochemicalApi.fetchAgrochemicals(
          treeUuid: widget.treeUuid,
        );
        return response;
      }
    } catch (e) {
      print('⚠️ Agrochemical fetch remote failed or no connectivity: $e');
    }

    // Offline or remote failed: read from local DB
    try {
      final local = await AgroDB().fetchByTreeUuid(widget.treeUuid);
      // Convert AgrochemicalModel -> Map<String,dynamic> shape expected by UI
      final mapped = local.map((AgrochemicalModel m) {
        return {
          'agrochemical': {
            'name': m.agrochemicalName ?? 'Unknown Agrochemical',
            'thumbnail': null,
          },
          'applied_at': m.applied_at ?? '',
          'description': m.description ?? '',
          'tree_uuid': m.tree_uuid ?? widget.treeUuid,
          // keep sync flags for UI/diagnostics
          'synced': m.synced,
          'pending_update': m.pendingUpdate,
          'pending_delete': m.pendingDelete,
        };
      }).toList();
      return mapped;
    } catch (e) {
      print('⚠️ Failed to read local agrochemical DB: $e');
      return <Map<String, dynamic>>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 🔍 Search + Add Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search Agrochemical',
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
                      builder:
                          (_) => CreateAgrochemicalPage(
                            treeUuid: widget.treeUuid,
                            treeTag: '',
                            agrochemicalRecord: null,
                          ),
                    ),
                  );
                  if (result == true) setState(() {}); // refresh after adding
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),

        // 📋 Agrochemical Records
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: fetchAgrochemical(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final items = snapshot.data ?? [];

              // Filter based on nested agrochemical name
              final filtered =
                  items.where((item) {
                    final name =
                        item['agrochemical']?['name']
                            ?.toString()
                            .toLowerCase() ??
                        '';
                    return name.contains(searchQuery.toLowerCase());
                  }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text('No agrochemical records found.'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final agro = item['agrochemical'] ?? {};
                  final isSelected = selectedIndex == index;

                  return GestureDetector(
                    onTap: () async {
                      setState(() => selectedIndex = index);

                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => CreateAgrochemicalPage(
                                treeUuid: widget.treeUuid,
                                treeTag: '', // Optional if needed
                                agrochemicalRecord:
                                    item, // ✅ pass the selected record
                              ),
                        ),
                      );

                      if (result == true) {
                        setState(() {}); // refresh list after update
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? Colors.blue : AppColors.gray300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        
                        title: Text(
                          agro['name'] ?? 'Unknown Agrochemical',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          "Applied at: ${item['applied_at'] ?? ''}",
                          style: const TextStyle(
                            color: AppColors.gray500,
                            fontSize: 15,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.hunterGreen,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
