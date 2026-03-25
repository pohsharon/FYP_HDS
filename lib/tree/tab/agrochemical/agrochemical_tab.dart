import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/agrochemical_api.dart';
import 'package:fyp_hbs/tree/tab/agrochemical/create_agrochemical.dart';
import 'package:fyp_hbs/tree/tab/agrochemical/agrochemical_list.dart';

/// Minimal agrochemical tab: fetches from server and shows a simple list.
class AgrochemicalTabPage extends StatefulWidget {
  final String treeUuid;
  final String treeTag;
  const AgrochemicalTabPage({
    super.key,
    required this.treeUuid,
    required this.treeTag,
  });

  @override
  State<AgrochemicalTabPage> createState() => _AgrochemicalTabPageState();
}

class _AgrochemicalTabPageState extends State<AgrochemicalTabPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await AgrochemicalApi.fetchAgrochemicals(
        treeUuid: widget.treeUuid,
      );
      setState(() => _items = data);
    } catch (e) {
      setState(() => _items = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.list_alt_rounded,
                  color: AppColors.hunterGreen,
                ),
                tooltip: 'View Agrochemical List',
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AgrochemicalListPage(),
                      ),
                    ),
              ),
              const SizedBox(width: 8),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => CreateAgrochemicalPage(
                            treeUuid: widget.treeUuid,
                            treeTag: widget.treeTag,
                            agrochemicalRecord: null,
                          ),
                    ),
                  );
                  if (result == true) _load();
                },
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                label: const Text('Add', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.hunterGreen,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? Center(
                    child: Text(
                      'No records',
                      style: TextStyle(color: AppColors.gray600),
                    ),
                  )
                  : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final agro = item['agrochemical'] ?? item;
                      final name =
                          (agro['name'] ??
                                  agro['agrochemical_name'] ??
                                  'Unknown')
                              .toString();
                      final appliedAt = item['applied_at']?.toString() ?? '';
                      return ListTile(
                        title: Text(name),
                        subtitle: appliedAt.isNotEmpty ? Text(appliedAt) : null,
                        onTap: () async {
                          final res = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => CreateAgrochemicalPage(
                                    treeUuid: widget.treeUuid,
                                    treeTag: widget.treeTag,
                                    agrochemicalRecord: item,
                                  ),
                            ),
                          );
                          if (res == true) _load();
                        },
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
