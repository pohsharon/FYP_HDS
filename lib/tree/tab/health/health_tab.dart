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
import 'package:intl/intl.dart';
import 'package:fyp_hbs/utils/connectivity_helper.dart';
import 'package:another_flushbar/flushbar.dart';

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
  List<Map<String, dynamic>> _diseaseList = [];
  String? _selectedDiseaseId;
  String _currentRecordedFrom = '';
  String _currentRecordedTo = '';
  final TextEditingController _diseaseFilterController = TextEditingController();
  final TextEditingController _recordedFromController = TextEditingController();
  final TextEditingController _recordedToController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDiseaseCache();
    _loadDiseases();
  }

  @override
  void dispose() {
    _diseaseFilterController.dispose();
    _recordedFromController.dispose();
    _recordedToController.dispose();
    super.dispose();
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
    }
  }

  Future<void> _loadDiseases() async {
    try {
      final rows = await DiseaseDB().getAllDiseases();
      setState(() {
        _diseaseList = rows.map((r) => Map<String, dynamic>.from(r)).toList();
      });
    } catch (e) {
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
          const SizedBox(height: 8),
          _buildActiveFilters(),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchRecords(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }

              var filteredRecords = snapshot.data ?? [];
              
              // Apply disease filter
              if (_selectedDiseaseId != null && _selectedDiseaseId!.isNotEmpty) {
                filteredRecords = filteredRecords.where((record) {
                  final did = (record['diseaseId'] ?? record['disease_id'])?.toString() ?? '';
                  return did == _selectedDiseaseId;
                }).toList();
              }
              
              // Apply date range filter
              DateTime? parseDate(String? s) {
                if (s == null || s.trim().isEmpty) return null;
                try {
                  return DateFormat('dd-MM-yyyy').parse(s);
                } catch (e) {
                  return null;
                }
              }
              
              final recordedFrom = parseDate(_currentRecordedFrom);
              final recordedTo = parseDate(_currentRecordedTo);
              
              if (recordedFrom != null || recordedTo != null) {
                filteredRecords = filteredRecords.where((record) {
                  final s = record['recorded_at']?.toString() ?? '';
                  final dt = DateTime.tryParse(s);
                  if (dt == null) return false;
                  if (recordedFrom != null && dt.isBefore(recordedFrom)) return false;
                  if (recordedTo != null && dt.isAfter(recordedTo)) return false;
                  return true;
                }).toList();
              }
              
              // Apply search query
              filteredRecords = filteredRecords.where((record) {
                final name = extractDiseaseName(record);
                return name.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                );
              }).toList();

              if (filteredRecords.isEmpty) {
                // If there are no records at all in the database, show initial message
                if (snapshot.data == null || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.gray200,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.health_and_safety_outlined,
                            size: 40,
                            color: AppColors.gray600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No health records yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gray700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the Add button to create your first record',
                          style: TextStyle(fontSize: 14, color: AppColors.gray600),
                        ),
                      ],
                    ),
                  );
                }
                
                // If records exist but filters removed them all, show filter message
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: AppColors.gray400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No records found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gray600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters or search',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

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

  Widget _buildActiveFilters() {
    final chips = <Widget>[];

    if (_selectedDiseaseId != null && _selectedDiseaseId!.isNotEmpty) {
      final diseaseName = _diseaseCache[_selectedDiseaseId] ?? _selectedDiseaseId;
      chips.add(
        _buildFilterChip(
          'Disease: $diseaseName',
          () {
            _diseaseFilterController.clear();
            setState(() {
              _selectedDiseaseId = null;
            });
          },
        ),
      );
    }

    if ((_currentRecordedFrom.isNotEmpty) || (_currentRecordedTo.isNotEmpty)) {
      String label;
      if (_currentRecordedFrom.isNotEmpty && _currentRecordedTo.isNotEmpty) {
        label = 'Recorded: $_currentRecordedFrom to $_currentRecordedTo';
      } else if (_currentRecordedFrom.isNotEmpty) {
        label = 'Recorded >= $_currentRecordedFrom';
      } else {
        label = 'Recorded <= $_currentRecordedTo';
      }

      chips.add(
        _buildFilterChip(
          label,
          () {
            _recordedFromController.clear();
            _recordedToController.clear();
            setState(() {
              _currentRecordedFrom = '';
              _currentRecordedTo = '';
            });
          },
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.filter_list,
            size: 18,
            color: AppColors.gray600,
          ),
          const SizedBox(width: 8),
          Text(
            'Active Filters:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.gray700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: chips.map((chip) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: chip,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onClear) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.hunterGreen.withOpacity(0.1),
            AppColors.mossGreen.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.hunterGreen.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onClear,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_alt,
                  size: 16,
                  color: AppColors.hunterGreen,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.hunterGreen,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.hunterGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
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
                onTap: () => _showFilterDialog(context),
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
        final hasInternet = await ConnectivityHelper.hasInternetConnection();
        if (!hasInternet) {
          if (mounted) {
            await Flushbar(
              message: 'Editing is disabled while offline',
              icon: const Icon(Icons.cloud_off, color: Colors.white),
              backgroundColor: Colors.orange.shade700,
              duration: const Duration(seconds: 2),
              borderRadius: BorderRadius.circular(12),
              margin: const EdgeInsets.all(12),
              flushbarPosition: FlushbarPosition.TOP,
            ).show(context);
          }
          return;
        }
        
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

  void _showFilterDialog(BuildContext context) async {
    // Ensure diseases are loaded before showing dialog
    if (_diseaseList.isEmpty) {
      await _loadDiseases();
    }

    String? tempSelectedDiseaseId = _selectedDiseaseId;
    final recordedFrom = TextEditingController(text: _currentRecordedFrom);
    final recordedTo = TextEditingController(text: _currentRecordedTo);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.white,
                  AppColors.background,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.hunterGreen,
                        AppColors.mossGreen,
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.filter_list,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Filter',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: StatefulBuilder(
                    builder: (context, setStateDialog) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildEnhancedSectionHeader("Disease", Icons.healing),
                            const SizedBox(height: 8),
                            _buildEnhancedDropdown(
                              context: context,
                              controller: _diseaseFilterController,
                              initialSelection: tempSelectedDiseaseId,
                              entries: [
                                const DropdownMenuEntry(
                                  value: '',
                                  label: 'All diseases',
                                ),
                                ..._diseaseList.map<DropdownMenuEntry<String>>(
                                  (disease) {
                                    final id = (disease['id'] ?? '').toString();
                                    final name = (disease['diseaseName'] ?? disease['disease_name'] ?? disease['name'] ?? '').toString();
                                    return DropdownMenuEntry(
                                      value: id.isNotEmpty ? id : '',
                                      label: name.isNotEmpty ? name : 'Unknown',
                                    );
                                  },
                                ),
                              ],
                              onSelected: (String? v) {
                                setStateDialog(
                                  () => tempSelectedDiseaseId = (v == null || v.isEmpty) ? null : v,
                                );
                              },
                            ),

                            const SizedBox(height: 20),
                            _buildEnhancedSectionHeader("Recorded Date Range", Icons.date_range),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildEnhancedDateField(
                                    context: context,
                                    controller: recordedFrom,
                                    label: 'From',
                                    icon: Icons.calendar_today,
                                    setStateDialog: setStateDialog,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildEnhancedDateField(
                                    context: context,
                                    controller: recordedTo,
                                    label: 'To',
                                    icon: Icons.event,
                                    setStateDialog: setStateDialog,
                                    minDate: recordedFrom.text.isNotEmpty
                                        ? DateTime.tryParse(recordedFrom.text)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _clearFilters();
                          },
                          icon: const Icon(Icons.clear_all, size: 18),
                          label: const Text("Reset"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.gray700,
                            side: BorderSide(color: AppColors.gray400, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.hunterGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: AppColors.hunterGreen.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            setState(() {
                              _selectedDiseaseId = tempSelectedDiseaseId;
                              _currentRecordedFrom = recordedFrom.text;
                              _currentRecordedTo = recordedTo.text;
                            });
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text(
                            "Apply Filters",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _clearFilters() {
    if (mounted) {
      setState(() {
        _selectedDiseaseId = null;
        _currentRecordedFrom = '';
        _currentRecordedTo = '';
        _diseaseFilterController.clear();
        _recordedFromController.clear();
        _recordedToController.clear();
      });
    }
  }

  Widget _buildEnhancedSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.hunterGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: AppColors.hunterGreen,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.gray800,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedDropdown({
    required BuildContext context,
    required TextEditingController controller,
    required String? initialSelection,
    required List<DropdownMenuEntry<String>> entries,
    required Function(String?) onSelected,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final menuWidth = constraints.maxWidth;
          return DropdownMenu<String>(
            width: menuWidth,
            menuHeight: 200,
            controller: controller,
            requestFocusOnTap: true,
            initialSelection: initialSelection ?? '',
            dropdownMenuEntries: entries,
            onSelected: onSelected,
            textStyle: const TextStyle(fontSize: 14),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedDateField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Function(void Function()) setStateDialog,
    DateTime? minDate,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: label,
          labelStyle: TextStyle(
            color: AppColors.gray600,
            fontSize: 13,
          ),
          prefixIcon: Icon(icon, size: 18, color: AppColors.hunterGreen),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 18, color: AppColors.gray600),
                  onPressed: () {
                    setStateDialog(() => controller.clear());
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: minDate ?? DateTime(2000),
            lastDate: DateTime.now(),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: AppColors.hunterGreen,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            setStateDialog(
              () => controller.text = DateFormat('dd-MM-yyyy').format(picked),
            );
          }
        },
      ),
    );
  }
}