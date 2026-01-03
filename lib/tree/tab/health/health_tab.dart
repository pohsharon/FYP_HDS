import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'create_health_info.dart';
import 'package:fyp_hbs/services/health_api.dart';
import 'disease_list.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../services/local database/health_db.dart';
import '../../../services/local database/disease_db.dart';
import '../../../config.dart';

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
  final Map<String, String> _diseaseCache = {};

  @override
  void initState() {
    super.initState();
    _loadDiseaseCache();
  }

  Future<void> _loadDiseaseCache() async {
    try {
      final rows = await DiseaseDB().getAllDiseases();
      final Map<String, String> map = {};
      for (final r in rows) {
        final id = (r['id'] ?? '').toString();
        final name = (r['disease_name'] ?? r['diseaseName'] ?? '').toString();
        if (id.isNotEmpty && name.isNotEmpty) map[id] = name;
      }
      if (mounted) setState(() => _diseaseCache
        ..clear()
        ..addAll(map));
    } catch (e) {
      print('⚠️ Failed to load disease cache: $e');
    }
  }

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
            future: _fetchRecords(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No health records found."));
              }

              final filteredRecords = snapshot.data!.where((record) {
                final name = extractDiseaseName(record);
                return name.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                );
              }).toList();

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

  Future<List<Map<String, dynamic>>> _fetchRecords() async {
    final conn = await Connectivity().checkConnectivity();
    final healthDB = HealthDB();

    if (conn == ConnectivityResult.none) {
      final local = await healthDB.fetchByTreeUuid(widget.treeUuid);
      return local.map((h) => h.toMap()).toList();
    }

    try {
      final remote = await HealthApi.fetchTreeHealthRecords(widget.treeUuid);
      if (remote.isEmpty) {
        final local = await healthDB.fetchByTreeUuid(widget.treeUuid);
        return local.map((h) => h.toMap()).toList();
      }
      return remote.map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (e) {
      final local = await healthDB.fetchByTreeUuid(widget.treeUuid);
      return local.map((h) => h.toMap()).toList();
    }
  }

  Widget _buildSearchAndAddButton() {
    return Row(
      children: [
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
                builder: (_) => const DiseaseListPage(),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
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
                onTap: () => setState(() => searchQuery = ''),
                child: const Icon(Icons.filter_alt_outlined),
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
        ElevatedButton.icon(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateHealthInfoPage(
                  treeTag: widget.treeTag,
                  treeUuid: widget.treeUuid,
                  existingRecord: null,
                ),
              ),
            );
            if (result == true) setState(() {});
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

  String extractDiseaseName(Map<String, dynamic> record) {
    try {
      if (record['disease'] is Map) {
        final d = record['disease'];
        return (d['diseaseName'] ?? d['name'] ?? '').toString();
      }
    } catch (_) {}
    
    final explicit = (record['disease_name'] ?? record['diseaseName'])?.toString() ?? '';
    if (explicit.isNotEmpty) return explicit;

    final did = (record['diseaseId'] ?? record['disease_id'])?.toString() ?? '';
    if (did.isNotEmpty) {
      final fromCache = _diseaseCache[did];
      if (fromCache != null && fromCache.isNotEmpty) return fromCache;
    }

    return '';
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    String recordedAt = record['recorded_at'] ?? "";
    String status = record['status'] ?? "";
    final diseaseName = extractDiseaseName(record);

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

    final thumbnail = (record['thumbnail'] ?? '').toString();
    final hasThumbnail = thumbnail.isNotEmpty;

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateHealthInfoPage(
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Disease name
                        Text(
                          diseaseName.isEmpty ? 'Unknown disease' : diseaseName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: AppColors.hunterGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Date and Status row
                        Row(
                          children: [
                            if (recordedAt.isNotEmpty) ...[
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: AppColors.gray600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                recordedAt,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.gray700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            // Status chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: statusColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Image thumbnail button
                  if (hasThumbnail) ...[
                    const SizedBox(width: 12),
                    Material(
                      color: AppColors.hunterGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showThumbnail(record),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.image_outlined,
                            color: AppColors.hunterGreen,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              // Treatment text
              if ((record['treatment'] ?? "").isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gray200.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.medical_services_outlined,
                        size: 16,
                        color: AppColors.gray600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          record['treatment'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.gray700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showThumbnail(Map<String, dynamic> record) {
    final thumb = (record['thumbnail'] ?? '').toString();
    if (thumb.isEmpty) return;

    final isHttp = thumb.startsWith('http');
    final isFile = thumb.startsWith('/') || thumb.startsWith('file:');
    final url = isHttp ? thumb : '${Config.supabaseBaseUrl}$thumb';

    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isFile
                  ? Image.file(File(thumb), fit: BoxFit.contain)
                  : Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.error_outline, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Image unavailable', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}