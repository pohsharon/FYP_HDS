import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'create_health_info.dart';
import 'disease_list.dart';
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
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _loading = true);
    try {
      final remote = await HealthApi.fetchTreeHealthRecords(widget.treeUuid);
      setState(() {
        _records = remote.map((m) => Map<String, dynamic>.from(m)).toList();
      });
    } catch (e) {
      setState(() => _records = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onAdd() async {
    final created = await Navigator.push<bool?>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateHealthInfoPage(
          treeTag: widget.treeTag,
          treeUuid: widget.treeUuid,
          existingRecord: null,
        ),
      ),
    );
    if (created == true) await _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    String _extractName(Map<String, dynamic> r) {
      try {
        final disease = r['disease'];
        if (disease is Map) {
          final n = disease['diseaseName'];
          if (n != null) return n.toString();
        }
        final n = r['diseaseName'];
        return n.toString();
      } catch (_) {
        return '';
      }
    }

    final filtered = _records.where((r) {
      final name = _extractName(r);
      return name.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Diseases',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DiseaseListPage()),
                  );
                  // refresh in case diseases changed
                  await _loadRecords();
                },
                icon: const Icon(Icons.medical_services_outlined),
                color: AppColors.hunterGreen,
              ),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search disease',
                    filled: true,
                    fillColor: AppColors.white,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.hunterGreen),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.health_and_safety_outlined, size: 48, color: AppColors.gray400),
                          const SizedBox(height: 12),
                          Text('No health records', style: TextStyle(color: AppColors.gray700)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = filtered[i];
                        final name = _extractName(item);
                        final recorded = item['recorded_at'].toString();
                        final note = item['treatment'].toString();

                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (recorded.isNotEmpty) Text(recorded, style: TextStyle(color: AppColors.gray600)),
                                if (note.isNotEmpty) Text(note, style: TextStyle(color: AppColors.gray600)),
                              ],
                            ),
                            onTap: () async {
                              final updated = await Navigator.push<bool?>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CreateHealthInfoPage(
                                    treeTag: widget.treeTag,
                                    treeUuid: widget.treeUuid,
                                    existingRecord: item,
                                  ),
                                ),
                              );
                              if (updated == true) await _loadRecords();
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
