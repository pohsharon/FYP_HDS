import 'package:flutter/material.dart';
import 'package:fyp_hbs/config.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/agrochemical_api.dart';
import 'package:fyp_hbs/tree/tab/agrochemical/create_agrochemical.dart';
import 'package:fyp_hbs/tree/tab/agrochemical/agrochemical_list.dart';
import 'package:fyp_hbs/utils/connectivity_helper.dart';
import 'package:fyp_hbs/services/local database/agro_db.dart';
import 'package:fyp_hbs/models/agrochemical_model.dart';
import 'package:intl/intl.dart';
import 'package:another_flushbar/flushbar.dart';

class AgrochemicalTabPage extends StatefulWidget {
  final String treeUuid;
  final String treeTag;
  const AgrochemicalTabPage({super.key, required this.treeUuid, required this.treeTag});

  @override
  State<AgrochemicalTabPage> createState() => _AgrochemicalTabPageState();
}

class _AgrochemicalTabPageState extends State<AgrochemicalTabPage> {
  String searchQuery = '';
  List<Map<String, dynamic>> _agrochemicalList = [];
  String? _selectedAgrochemicalId;
  String _currentAppliedFrom = '';
  String _currentAppliedTo = '';
  final TextEditingController _agrochemicalFilterController = TextEditingController();
  final TextEditingController _appliedFromController = TextEditingController();
  final TextEditingController _appliedToController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAgrochemicals();
  }

  @override
  void dispose() {
    _agrochemicalFilterController.dispose();
    _appliedFromController.dispose();
    _appliedToController.dispose();
    super.dispose();
  }

  Future<void> _loadAgrochemicals() async {
    try {
      final online = await ConnectivityHelper.hasInternetConnection();
      List<Map<String, dynamic>> list = [];
      
      if (online) {
        try {
          list = await AgrochemicalApi.getAgrochemical();
        } catch (e) {
          print('Failed to load agrochemicals from API: $e');
        }
      }
      
      if (list.isEmpty) {
        final local = await AgroDB().getAllAgrochemicals();
        list = local.map((m) => {
          'uuid': m['agrochemicalId'] ?? m['uuid'] ?? m['id'],
          'id': m['agrochemicalId'] ?? m['uuid'] ?? m['id'],
          'name': m['name'] ?? m['agrochemical_name'] ?? 'Unknown',
          'agrochemical_name': m['name'] ?? m['agrochemical_name'],
        }).toList();
      }
      
      if (mounted) {
        setState(() => _agrochemicalList = list);
      }
    } catch (e) {
      print('Failed to load agrochemicals: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchAgrochemical() async {
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

    try {
      final local = await AgroDB().fetchByTreeUuid(widget.treeUuid);
      final mapped = local.map((AgrochemicalModel m) {
        return {
          'agrochemical': {
            'name': m.agrochemicalName ?? 'Unknown Agrochemical',
            'thumbnail': null,
            'uuid': m.agrochemicalId,
            'id': m.agrochemicalId,
          },
          'applied_at': m.applied_at ?? '',
          'description': m.description ?? '',
          'tree_uuid': m.tree_uuid ?? widget.treeUuid,
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

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'No date';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _getTimeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      // If the selected date is today (ignoring time), show 'Today'
      final isSameDay = date.year == now.year && date.month == now.month && date.day == now.day;
      if (isSameDay) return 'Today';

      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()}y ago';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()}mo ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else {
        return 'Today';
      }
    } catch (e) {
      return '';
    }
  }

  Color _getAgrochemicalColor(int index) {
    final colors = [
      AppColors.hunterGreen,
      AppColors.mossGreen,
      Colors.teal,
      Colors.green.shade700,
      Colors.lightGreen.shade700,
    ];
    return colors[index % colors.length];
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
              IconButton(
                icon: const Icon(
                  Icons.list_alt_rounded,
                  color: AppColors.hunterGreen,
                ),
                tooltip: 'View Agrochemical List',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AgrochemicalListPage(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
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
                      onTap: () => _showFilterDialog(context),
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
                      builder: (_) => CreateAgrochemicalPage(
                        treeUuid: widget.treeUuid,
                        treeTag: widget.treeTag,
                        agrochemicalRecord: null,
                      ),
                    ),
                  );
                  if (result == true) setState(() {});
                },
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                label: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.hunterGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),

        // Filter chips
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildActiveFilters(),
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
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: AppColors.danger),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading records',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        style: TextStyle(fontSize: 12, color: AppColors.gray600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              
              var items = snapshot.data ?? [];
              
              // Check if there are any records at all before filtering
              final hasAnyRecords = items.isNotEmpty;
              
              // Apply agrochemical filter
              if (_selectedAgrochemicalId != null && _selectedAgrochemicalId!.isNotEmpty) {
                items = items.where((item) {
                  // Check multiple possible locations for the agrochemical ID
                  final agroId = (
                    item['agrochemical']?['uuid'] ?? 
                    item['agrochemical']?['id'] ?? 
                    item['agrochemical_id'] ??  // Top-level field
                    item['agrochemical_uuid'] ?? // Alternative top-level field
                    ''
                  ).toString();
                  return agroId == _selectedAgrochemicalId;
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
              
              final appliedFrom = parseDate(_currentAppliedFrom);
              final appliedTo = parseDate(_currentAppliedTo);
              
              if (appliedFrom != null || appliedTo != null) {
                items = items.where((item) {
                  final s = item['applied_at']?.toString() ?? '';
                  final dt = DateTime.tryParse(s);
                  if (dt == null) return false;
                  if (appliedFrom != null && dt.isBefore(appliedFrom)) return false;
                  if (appliedTo != null && dt.isAfter(appliedTo)) return false;
                  return true;
                }).toList();
              }
              
              final filtered = items.where((item) {
                final name = item['agrochemical_name']?['name']?.toString().toLowerCase() ?? '';
                return name.contains(searchQuery.toLowerCase());
              }).toList();

              if (filtered.isEmpty) {
                // If there are no records at all in the database, show initial message
                if (!hasAnyRecords) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.gray200,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.science_outlined,
                            size: 40,
                            color: AppColors.gray600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No agrochemical records yet',
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 36,
                          color: AppColors.gray400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No records found',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gray600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try adjusting your filters or search',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final agro = item['agrochemical'] ?? {};
                  final cardColor = _getAgrochemicalColor(index);
                  final thumbRaw = (agro['thumbnail'] ?? item['thumbnail'] ?? '').toString();
                  final thumb = thumbRaw.isNotEmpty ? '${Config.supabaseBaseUrl}$thumbRaw' : '';
                  final hasThumb = thumb.isNotEmpty;
                  final appliedAt = item['applied_at']?.toString() ?? '';
                  final description = item['description']?.toString() ?? '';

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
                          builder: (_) => CreateAgrochemicalPage(
                            treeUuid: widget.treeUuid,
                            treeTag: widget.treeTag,
                            agrochemicalRecord: item,
                          ),
                        ),
                      );

                      if (result == true) {
                        setState(() {});
                      }
                    },
                    child: Card(
                      elevation: 2,
                      shadowColor: Colors.black.withOpacity(0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: AppColors.gray200,
                          width: 1,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: AppColors.white,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Thumbnail or fallback icon
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: hasThumb ? Colors.transparent : cardColor,
                                  gradient: hasThumb
                                      ? null
                                      : LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [cardColor, cardColor.withOpacity(0.7)],
                                        ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: cardColor.withOpacity(0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: hasThumb
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          thumb,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Center(
                                            child: Icon(Icons.science, color: Colors.white, size: 28),
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.science, color: Colors.white, size: 28),
                              ),

                              const SizedBox(width: 16),

                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Agrochemical Name
                                    Text(
                                      agro['name'] ?? 'Unknown Agrochemical',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                        color: AppColors.gray900,
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    // Applied Date Row
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: AppColors.gray600,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatDate(appliedAt),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.gray700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (appliedAt.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: cardColor.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: cardColor.withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              _getTimeAgo(appliedAt),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: cardColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),

                                    // Description (if available)
                                    if (description.isNotEmpty) ...[
                                      const SizedBox(height: 8),
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
                                              Icons.notes,
                                              size: 14,
                                              color: AppColors.gray600,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                description,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.gray700,
                                                  height: 1.3,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Chevron Icon
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.gray200.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.chevron_right,
                                  color: AppColors.gray600,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildActiveFilters() {
    final chips = <Widget>[];

    if (_selectedAgrochemicalId != null && _selectedAgrochemicalId!.isNotEmpty) {
      final agroName = _agrochemicalList
          .where((a) => (a['uuid'] ?? a['id']).toString() == _selectedAgrochemicalId)
          .firstOrNull
          ?['name'] ?? _selectedAgrochemicalId;
      chips.add(
        _buildFilterChip(
          'Agrochemical: $agroName',
          () {
            _agrochemicalFilterController.clear();
            setState(() {
              _selectedAgrochemicalId = null;
            });
          },
        ),
      );
    }

    if ((_currentAppliedFrom.isNotEmpty) || (_currentAppliedTo.isNotEmpty)) {
      String label;
      if (_currentAppliedFrom.isNotEmpty && _currentAppliedTo.isNotEmpty) {
        label = 'Applied: $_currentAppliedFrom to $_currentAppliedTo';
      } else if (_currentAppliedFrom.isNotEmpty) {
        label = 'Applied >= $_currentAppliedFrom';
      } else {
        label = 'Applied <= $_currentAppliedTo';
      }

      chips.add(
        _buildFilterChip(
          label,
          () {
            _appliedFromController.clear();
            _appliedToController.clear();
            setState(() {
              _currentAppliedFrom = '';
              _currentAppliedTo = '';
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
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
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

  void _showFilterDialog(BuildContext context) async {
    if (_agrochemicalList.isEmpty) {
      await _loadAgrochemicals();
    }

    String? tempSelectedAgrochemicalId = _selectedAgrochemicalId;
    final appliedFrom = TextEditingController(text: _currentAppliedFrom);
    final appliedTo = TextEditingController(text: _currentAppliedTo);

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
                            _buildEnhancedSectionHeader("Agrochemical", Icons.science),
                            const SizedBox(height: 8),
                            _buildEnhancedDropdown(
                              context: context,
                              controller: _agrochemicalFilterController,
                              initialSelection: tempSelectedAgrochemicalId,
                              entries: [
                                const DropdownMenuEntry(
                                  value: '',
                                  label: 'All agrochemicals',
                                ),
                                ..._agrochemicalList.map<DropdownMenuEntry<String>>(
                                  (agro) {
                                    final id = (agro['uuid'] ?? agro['id'] ?? '').toString();
                                    final name = (agro['name'] ?? agro['agrochemical_name'] ?? '').toString();
                                    return DropdownMenuEntry(
                                      value: id.isNotEmpty ? id : '',
                                      label: name.isNotEmpty ? name : 'Unknown',
                                    );
                                  },
                                ),
                              ],
                              onSelected: (String? v) {
                                setStateDialog(
                                  () => tempSelectedAgrochemicalId = (v == null || v.isEmpty) ? null : v,
                                );
                              },
                            ),

                            const SizedBox(height: 20),
                            _buildEnhancedSectionHeader("Applied Date Range", Icons.date_range),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildEnhancedDateField(
                                    context: context,
                                    controller: appliedFrom,
                                    label: 'From',
                                    icon: Icons.calendar_today,
                                    setStateDialog: setStateDialog,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildEnhancedDateField(
                                    context: context,
                                    controller: appliedTo,
                                    label: 'To',
                                    icon: Icons.event,
                                    setStateDialog: setStateDialog,
                                    minDate: appliedFrom.text.isNotEmpty
                                        ? DateTime.tryParse(appliedFrom.text)
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
                              _selectedAgrochemicalId = tempSelectedAgrochemicalId;
                              _currentAppliedFrom = appliedFrom.text;
                              _currentAppliedTo = appliedTo.text;
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
        _selectedAgrochemicalId = null;
        _currentAppliedFrom = '';
        _currentAppliedTo = '';
        _agrochemicalFilterController.clear();
        _appliedFromController.clear();
        _appliedToController.clear();
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