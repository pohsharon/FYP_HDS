import 'package:flutter/material.dart';
import 'package:fyp_hbs/config.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/agrochemical_api.dart';
import 'package:fyp_hbs/tree/tab/agrochemical/create_agrochemical.dart';

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
    final response = await AgrochemicalApi.fetchAgrochemicals(
      treeUuid: widget.treeUuid,
    );
    return response;
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
                    onTap: () {
                      setState(() => selectedIndex = index);
                      // TODO: Navigate to details page
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
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child:
                              agro['thumbnail'] != null
                                  ? Image.network(
                                    "${Config.apiBaseUrl}/${agro['thumbnail']}",
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  )
                                  : Container(
                                    width: 50,
                                    height: 50,
                                    color: AppColors.gray200,
                                    child: const Icon(
                                      Icons.image,
                                      color: Colors.grey,
                                    ),
                                  ),
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
