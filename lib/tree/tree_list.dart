import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/tree/tree_details.dart';
import 'package:fyp_hbs/tree/create_tree.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fyp_hbs/services/api/tree_api.dart';
// AppInitializer is invoked from the shared PersistentAppBar when manual sync is requested.
import 'package:another_flushbar/flushbar.dart';
import 'package:fyp_hbs/services/local%20database/tree_db.dart';
import 'package:fyp_hbs/services/api/auth_service.dart';
import 'package:fyp_hbs/services/local%20database/species_db.dart';
import 'package:fyp_hbs/services/app_initializer.dart';
import 'package:fyp_hbs/models/tree_model.dart';
import 'package:intl/intl.dart';
import 'package:fyp_hbs/tree/map.dart';
import 'package:fyp_hbs/authentication/login.dart';
import 'package:fyp_hbs/authentication/reset_password.dart';
import 'package:fyp_hbs/widgets/persistent_appbar.dart';
import 'package:fyp_hbs/services/api/disease_api.dart';
import 'package:fyp_hbs/services/api/agrochemical_api.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class TreePage extends StatefulWidget {
  const TreePage({super.key});

  @override
  State<TreePage> createState() => _TreePageState();
}

class _TreePageState extends State<TreePage> {
  // removed unused _treesFuture
  List<dynamic> trees = [];
  List<dynamic> _allTrees = [];
  List<dynamic> _filteredTrees = [];
  final List<String> _speciesList = [];
  List<Map<String, dynamic>> _diseaseList = [];
    List<Map<String, dynamic>> _agrochemicalList = [];
  String? _selectedSpecies;
    String? _selectedAgrochemicalId;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  // Controllers for matching create_tree's DropdownMenu style
  final TextEditingController _speciesFilterController =
      TextEditingController();
  final TextEditingController _diseaseFilterController =
      TextEditingController();
    final TextEditingController _agrochemicalFilterController =
      TextEditingController();

  int _currentPage = 1;
  int _lastPage = 1;
  bool _isLoadingMore = false;
  bool _isInitialLoading = true;
  bool _isOnline = true;
  // Persistent filter state so dialog opens with current values
  // Planting date filter state
  String _currentPlantingFrom = '';
  String _currentPlantingTo = '';
  String? _selectedDiseaseId;
  final TextEditingController _plantingFromController = TextEditingController();
  final TextEditingController _plantingToController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchTrees(page: 1);
    // Populate species dropdown from local DB so the 'All species' list is available offline
    _loadLocalSpecies();
    _loadDiseases();
    _loadAgrochemicals();
    _checkOnline();
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((status) {
      final onlineNow = status.any((s) => s != ConnectivityResult.none);
      if (mounted) {
        setState(() {
          _isOnline = onlineNow;
        });
      }
    });

    // Listen for sync completion and auto-refresh
    AppInitializer.syncCompleted.addListener(_onSyncCompleted);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _currentPage < _lastPage) {
        // Load next page when near bottom
        _loadMoreTrees();
      }
    });
  }

  void _onSyncCompleted() {
    if (mounted) {
      _currentPage = 1;
      fetchTrees(page: 1);
    }
  }

  Future<void> _checkOnline() async {
    final status = await Connectivity().checkConnectivity();
    final onlineNow = status != ConnectivityResult.none;
    if (mounted) {
      setState(() {
        _isOnline = onlineNow;
      });
    }
  }

  Future<void> _loadLocalSpecies() async {
    try {
      final rows = await SpeciesDB().getAllSpecies();
      final names = <String>[];
      for (final s in rows) {
        final n = s['name']?.toString() ?? '';
        if (n.isNotEmpty) names.add(n);
      }

      if (mounted) {
        setState(() {
          _speciesList.clear();
          _speciesList.addAll(names);
        });
      }
    } catch (e) {
      // Non-fatal: silently continue (dialog will show empty if no species available)
    }
  }

  Future<void> _loadDiseases() async {
    try {
      final diseases = await DiseaseApi.fetchDiseases();
      if (mounted) {
        setState(() {
          _diseaseList = diseases;
        });
      }
    } catch (e) {
    }
  }

  Future<void> _loadAgrochemicals() async {
    try {
      final agrochemicals = await AgrochemicalApi.getAgrochemical();
      if (mounted) {
        setState(() {
          _agrochemicalList = agrochemicals;
        });
      }
    } catch (e) {
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    AppInitializer.syncCompleted.removeListener(_onSyncCompleted);
    _scrollController.dispose();
    _speciesFilterController.dispose();
    _diseaseFilterController.dispose();
    _agrochemicalFilterController.dispose();
    _plantingFromController.dispose();
    _plantingToController.dispose();
    super.dispose();
  }

  bool _hasActiveFilters() {
    return _selectedSpecies != null ||
        _selectedDiseaseId != null ||
        _selectedAgrochemicalId != null ||
        _currentPlantingFrom.isNotEmpty ||
        _currentPlantingTo.isNotEmpty;
  }

  Future<void> _loadMoreTrees() async {
    if (mounted) {
      setState(() => _isLoadingMore = true);
    }
    await fetchTrees(page: _currentPage + 1, isLoadMore: true);
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  void filterTrees(String query) {
    final filtered =
        _allTrees.where((tree) {
          final treeId = tree['tree_tag']?.toString().toLowerCase() ?? '';
          return treeId.contains(query.toLowerCase());
        }).toList();
    if (mounted) {
      setState(() {
        _filteredTrees = filtered;
        _isInitialLoading = false;
      });
    }
  }

  Future<void> fetchTrees({int page = 1, bool isLoadMore = false}) async {
    if (!isLoadMore && page == 1) {
      if (mounted) {
        setState(() {
          _isInitialLoading = true;
          // Clear existing trees when refreshing from page 1
          _filteredTrees = [];
          _allTrees = [];
        });
      }
    }
    try {
      final response = await TreeApi.fetchTrees(page: page);

      final pagination = response['data'] as Map<String, dynamic>;
      final List<dynamic> treeList = pagination['data'] ?? [];
      final int lastPage = pagination['last_page'] ?? 1;

      // 💾 Cache fetched trees to local DB immediately so offline mode has latest data
      try {
        for (final tree in treeList) {
          if (tree is Map<String, dynamic>) {
            await TreeDB().upsertTreeFromApi(tree);
          }
        }
      } catch (e) {
        print('⚠️ Failed to cache fetched trees to local DB: $e');
      }

      final cleanedTrees =
          treeList.map((tree) {
            final t = tree as Map<String, dynamic>;
            return {
              ...t,
              'latitude': t['latitude'] ?? 0.0,
              'longitude': t['longitude'] ?? 0.0,
            };
          }).toList();

      // Merge local unsynced trees (if any) so they appear at the top of the list.
      List<dynamic> merged = List<Map<String, dynamic>>.from(cleanedTrees);
      try {
        final localUnsynced = await TreeDB().fetchUnsyncedTrees();
        final mappedLocal =
            localUnsynced.map((TreeModel m) {
              return {
                'id': m.id ?? m.uuid,
                'uuid': m.uuid,
                'tree_tag': m.treeTag ?? 'Offline Tree',
                'species': {
                  'id': m.speciesId,
                  'name': m.speciesId ?? 'Unknown',
                },
                'planted_at':
                    m.plantedAt != null
                        ? DateFormat('yyyy-MM-dd').format(m.plantedAt!)
                        : '',
                'latitude': m.latitude ?? 0.0,
                'longitude': m.longitude ?? 0.0,
                'thumbnail': m.thumbnail ?? '',
                'height': m.height ?? 0.0,
                'diameter': m.diameter ?? 0.0,
                'flowering_period': m.floweringPeriod ?? 0,
                'synced': m.synced,
              };
            }).toList();

        // Prepend local unsynced items, avoiding duplicates by uuid
        final seen = <String>{};
        final combined = <Map<String, dynamic>>[];

        for (final l in mappedLocal) {
          final lu = (l['uuid'] ?? '').toString();
          if (lu.isNotEmpty && !seen.contains(lu)) {
            combined.add(l);
            seen.add(lu);
          }
        }

        for (final r in merged) {
          final ru = (r['uuid'] ?? r['id'] ?? '').toString();
          if (ru.isNotEmpty && !seen.contains(ru)) {
            combined.add(Map<String, dynamic>.from(r));
            seen.add(ru);
          }
        }

        // Ensure unsynced (local) rows appear at the top. Also try to sort by
        // numeric sequence parsed from the tag (desc) so latest tags show first.
        combined.sort((a, b) {
          final aSyn =
              (a['synced'] == 0 || a['synced']?.toString() == '0') ? 0 : 1;
          final bSyn =
              (b['synced'] == 0 || b['synced']?.toString() == '0') ? 0 : 1;
          if (aSyn != bSyn) return aSyn - bSyn; // unsynced (0) first

          // both same sync status: try to compare sequence number parsed from 'tree_tag'
          int parseSeq(Map<String, dynamic> m) {
            final tag = (m['tree_tag'] ?? '').toString();
            if (!tag.contains('-')) return 0;
            final parts = tag.split('-');
            final seq = parts.last.replaceAll(RegExp(r'[^0-9]'), '');
            return int.tryParse(seq) ?? 0;
          }

          final aSeq = parseSeq(a);
          final bSeq = parseSeq(b);
          // larger sequence first
          return bSeq.compareTo(aSeq);
        });

        if (!mounted) return;
        setState(() {
          _lastPage = lastPage;

          // When loading more pages, merge with existing filtered trees
          // When loading page 1 (refresh), start fresh with combined results
          final baseList = isLoadMore ? List<Map<String, dynamic>>.from(_filteredTrees) : <Map<String, dynamic>>[];
          final mergedAll = [...baseList, ...combined];

          // Deduplicate by uuid
          final seen = <String>{};
          final unique = <Map<String, dynamic>>[];

          for (final t in mergedAll) {
            final u = (t['uuid'] ?? t['id'] ?? '').toString();
            if (u.isNotEmpty && !seen.contains(u)) {
              unique.add(t);
              seen.add(u);
            }
          }

          // 🔑 Enforce offline-first ordering
          unique.sort((a, b) {
            final aSyn =
                (a['synced'] == 0 || a['synced']?.toString() == '0') ? 0 : 1;
            final bSyn =
                (b['synced'] == 0 || b['synced']?.toString() == '0') ? 0 : 1;
            if (aSyn != bSyn) return aSyn - bSyn;

            int parseSeq(Map<String, dynamic> m) {
              final tag = (m['tree_tag'] ?? '').toString();
              final seq = RegExp(r'\d+$').firstMatch(tag)?.group(0);
              return int.tryParse(seq ?? '') ?? 0;
            }

            return parseSeq(b).compareTo(parseSeq(a));
          });

          _filteredTrees = unique;
          _allTrees = unique;
          _isInitialLoading = false;
        });
      } catch (e) {
        // If anything goes wrong merging local unsynced, fall back to remote-only list
        if (!mounted) return;
        setState(() {
          _lastPage = lastPage;
          if (isLoadMore) {
            _filteredTrees.addAll(cleanedTrees);
          } else {
            _filteredTrees = cleanedTrees;
            _allTrees = cleanedTrees;
          }
          _isInitialLoading = false;
        });
      }

      _currentPage = page;
    } catch (e) {
      print('Offline mode: falling back to local DB');

      try {
        final local = await TreeDB().fetchAllTrees();
        // build species lookup from local species table
        final speciesRows = await SpeciesDB().getAllSpecies();
        final Map<String, String> speciesLookup = {};
        for (final s in speciesRows) {
          final key = s['id']?.toString();
          final name = s['name']?.toString() ?? '';
          if (key != null) speciesLookup[key] = name;
        }

        final cleanedLocal =
            local.map((TreeModel m) {
              final sid = m.speciesId?.toString();
              final speciesName =
                  (sid != null && speciesLookup.containsKey(sid))
                      ? speciesLookup[sid]
                      : (m.speciesId ?? 'Unknown');

              return {
                'id': m.id ?? m.uuid,
                'uuid': m.uuid,
                'tree_tag': m.treeTag ?? 'Offline Tree',
                'species': {'id': m.speciesId, 'name': speciesName},
                'planted_at':
                    m.plantedAt != null
                        ? DateFormat('yyyy-MM-dd').format(m.plantedAt!)
                        : '',
                'latitude': m.latitude ?? 0.0,
                'longitude': m.longitude ?? 0.0,
                'thumbnail': m.thumbnail ?? '',
                'height': m.height ?? 0.0,
                'diameter': m.diameter ?? 0.0,
                'flowering_period': m.floweringPeriod ?? 0,
                'synced': m.synced,
              };
            }).toList();

        // Sort offline trees: unsynced first, then by sequence number descending
        cleanedLocal.sort((a, b) {
          final aSyn =
              (a['synced'] == 0 || a['synced']?.toString() == '0') ? 0 : 1;
          final bSyn =
              (b['synced'] == 0 || b['synced']?.toString() == '0') ? 0 : 1;
          if (aSyn != bSyn) return aSyn - bSyn; // unsynced (0) first

          int parseSeq(Map<String, dynamic> m) {
            final tag = (m['tree_tag'] ?? '').toString();
            final seq = RegExp(r'\d+$').firstMatch(tag)?.group(0);
            return int.tryParse(seq ?? '') ?? 0;
          }

          return parseSeq(b).compareTo(parseSeq(a)); // larger sequence first
        });

        if (!mounted) return;

        setState(() {
          _lastPage = 1;
          
          // When in offline mode, deduplicate before displaying
          final baseList = isLoadMore ? List<Map<String, dynamic>>.from(_filteredTrees) : <Map<String, dynamic>>[];
          final mergedAll = [...baseList, ...cleanedLocal];
          
          // Deduplicate by uuid
          final seen = <String>{};
          final unique = <Map<String, dynamic>>[];
          
          for (final t in mergedAll) {
            final u = (t['uuid'] ?? t['id'] ?? '').toString();
            if (u.isNotEmpty && !seen.contains(u)) {
              unique.add(t);
              seen.add(u);
            }
          }
          
          _filteredTrees = unique;
          _allTrees = unique;
          _isInitialLoading = false;
        });
      } catch (e2) {
        print('Failed to load trees from local DB: $e2');
        if (mounted) {
          setState(() {
            _isInitialLoading = false;
          });
        }
      }
    }
  }

  Future<void> _handleNavigationResult(dynamic result) async {
    if (result == null) return;

    final bool shouldRefresh =
        result == true || (result is Map && result['refreshList'] == true);

    // Back-compat: handle older flow that returns a created uuid map
    final String? createdUuid =
        result is Map && result['createdUuid'] != null
            ? result['createdUuid'].toString()
            : null;

    if (shouldRefresh) {
      await fetchTrees();
    }

    if (createdUuid != null && mounted) {
      await fetchTrees();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TreeDetailsPage(
            treeID: createdUuid,
            refreshOnPop: true,
          ),
        ),
      );
    }
  }

  void _showSpeciesFilterDialog(BuildContext context) async {
  if (_diseaseList.isEmpty) {
    await _loadDiseases();
  }
  if (_agrochemicalList.isEmpty) {
    await _loadAgrochemicals();
  }
  
  String? tempSelectedSpecies = _selectedSpecies;
  String? tempSelectedDiseaseId = _selectedDiseaseId;
  String? tempSelectedAgrochemicalId = _selectedAgrochemicalId;
  final plantingFrom = TextEditingController(text: _currentPlantingFrom);
  final plantingTo = TextEditingController(text: _currentPlantingTo);

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
                        Icons.tune,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Filter & Sort",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
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
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEnhancedSectionHeader("Species", Icons.eco),
                          const SizedBox(height: 8),
                          _buildEnhancedDropdown(
                            context: context,
                            controller: _speciesFilterController,
                            initialSelection: tempSelectedSpecies ?? '',
                            entries: [
                              const DropdownMenuEntry(
                                value: '',
                                label: 'All species',
                              ),
                              ..._speciesList.map<DropdownMenuEntry<String>>(
                                (species) => DropdownMenuEntry(
                                  value: species,
                                  label: species,
                                ),
                              ),
                            ],
                            onSelected: (String? v) {
                              setStateDialog(() => tempSelectedSpecies = v);
                            },
                          ),

                          const SizedBox(height: 20),
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
                                (disease) => DropdownMenuEntry(
                                  value: disease['id'].toString(),
                                  label: disease['diseaseName'] ?? disease['disease_name'] ?? '',
                                ),
                              ),
                            ],
                            onSelected: (String? v) {
                              setStateDialog(
                                () => tempSelectedDiseaseId = (v == null || v.isEmpty) ? null : v,
                              );
                            },
                          ),

                          const SizedBox(height: 20),
                          _buildEnhancedSectionHeader(
                            "Agrochemical",
                            Icons.science,
                          ),
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
                              ..._agrochemicalList
                                  .map<DropdownMenuEntry<String>>(
                                    (agro) {
                                      final id = (agro['uuid'] ?? agro['id'] ?? '').toString();
                                      final label = (agro['name'] ?? agro['agrochemical_name'] ?? agro['agrochemicalName'] ?? '').toString();
                                      return DropdownMenuEntry(
                                        value: id,
                                        label: label.isNotEmpty ? label : id,
                                      );
                                    },
                                  )
                                  .toList(),
                            ],
                            onSelected: (String? v) {
                              setStateDialog(
                                () => tempSelectedAgrochemicalId = (v == null || v.isEmpty) ? null : v,
                              );
                            },
                          ),

                          const SizedBox(height: 20),
                          _buildEnhancedSectionHeader("Planting Date Range", Icons.date_range),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildEnhancedDateField(
                                  context: context,
                                  controller: plantingFrom,
                                  label: 'From',
                                  icon: Icons.calendar_today,
                                  setStateDialog: setStateDialog,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildEnhancedDateField(
                                  context: context,
                                  controller: plantingTo,
                                  label: 'To',
                                  icon: Icons.event,
                                  setStateDialog: setStateDialog,
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
                          _clearSpeciesFilter();
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
                          _applyFilters(
                            species: tempSelectedSpecies,
                            plantingFrom: plantingFrom.text,
                            plantingTo: plantingTo.text,
                            diseaseId: tempSelectedDiseaseId,
                            agrochemicalId: tempSelectedAgrochemicalId,
                          );
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

  // Helper: Section Headers
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
          menuHeight: 300,
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
        labelText: label,
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
          firstDate: DateTime(2000),
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
            () => controller.text = DateFormat('yyyy-MM-dd').format(picked),
          );
        }
      },
    ),
  );
}

  // Sort helper removed — replaced by planting date range fields in the dialog.

  // Apply composite filters and sorting to _allTrees then set _filteredTrees
  void _applyFilters({
    String? species,
    String? plantingFrom,
    String? plantingTo,
    String? diseaseId,
    String? agrochemicalId,
  }) async {
    // Start from the full list
    List<dynamic> working = List<dynamic>.from(_allTrees);

    // Agrochemical filter: fetch trees with specific agrochemical and intersect
    if (agrochemicalId != null && agrochemicalId.isNotEmpty) {
      try {
        final treesWithAgro =
            await AgrochemicalApi.fetchTreesByAgrochemical(agrochemicalId);
        final agroTreeIds = <String>{};
        for (final t in treesWithAgro) {
          final treeData = t['tree'] ?? t;
          final uuid = (treeData['uuid'] ?? '').toString();
          final id = (treeData['id'] ?? '').toString();
          final finalId = uuid.isNotEmpty ? uuid : id;
          if (finalId.isNotEmpty) {
            agroTreeIds.add(finalId);
          }
        }
        working = working.where((tree) {
          final treeId = (tree['uuid'] ?? tree['id'] ?? '').toString();
          return agroTreeIds.contains(treeId);
        }).toList();
      } catch (e) {
        print('Error fetching trees by agrochemical: $e');
      }
    }

    // Disease filter: fetch trees with specific disease and intersect
    if (diseaseId != null && diseaseId.isNotEmpty) {
      try {
        final treesWithDisease = await DiseaseApi.fetchTreesByDisease(diseaseId);
        final diseaseTreeIds = <String>{};
        for (final t in treesWithDisease) {
          // The API returns nested structure: {tree: {...}, disease: {...}, health_records: [...]}
          final treeData = t['tree'];
          if (treeData != null) {
            final uuid = (treeData['uuid'] ?? '').toString();
            final id = (treeData['id'] ?? '').toString();
            final finalId = uuid.isNotEmpty ? uuid : id;
            if (finalId.isNotEmpty) {
              diseaseTreeIds.add(finalId);
            }
          }
        }
        working = working.where((tree) {
          final treeId = (tree['uuid'] ?? tree['id'] ?? '').toString();
          return diseaseTreeIds.contains(treeId);
        }).toList();
      } catch (e) {
        print('Error fetching trees by disease: $e');
      }
    }

    // Species filter
    if (species != null && species.isNotEmpty) {
      working =
          working.where((tree) {
            final name = tree['species']?['name']?.toString() ?? '';
            return name == species;
          }).toList();
    }



    // Apply planting date range if provided
    DateTime? parseDate(String? s) {
      if (s == null || s.trim().isEmpty) return null;
      return DateTime.tryParse(s);
    }

    final pFrom = parseDate(plantingFrom);
    final pTo = parseDate(plantingTo);
    if (pFrom != null || pTo != null) {
      working =
          working.where((tree) {
            final s = tree['planted_at']?.toString() ?? '';
            final dt = DateTime.tryParse(s);
            if (dt == null) return false;
            if (pFrom != null && dt.isBefore(pFrom)) return false;
            if (pTo != null && dt.isAfter(pTo)) return false;
            return true;
          }).toList();
    }

    if (mounted) {
      setState(() {
        _selectedSpecies = (species == null || species.isEmpty) ? null : species;
        _selectedDiseaseId = (diseaseId == null || diseaseId.isEmpty) ? null : diseaseId;
        _selectedAgrochemicalId =
            (agrochemicalId == null || agrochemicalId.isEmpty)
                ? null
                : agrochemicalId;
        _currentPlantingFrom = plantingFrom ?? '';
        _currentPlantingTo = plantingTo ?? '';
        _filteredTrees = working;
      });
    }
  }

  // Note: species-specific quick filter removed in favour of composite filters

  void _clearSpeciesFilter() {
    if (mounted) {
      setState(() {
        _selectedSpecies = null;
        _selectedDiseaseId = null;
        _selectedAgrochemicalId = null;
        _currentPlantingFrom = '';
        _currentPlantingTo = '';
        _diseaseFilterController.clear();
        _speciesFilterController.clear();
        _agrochemicalFilterController.clear();
        _filteredTrees = _allTrees;
      });
    }
  }

  String? _diseaseNameById(String? id) {
    if (id == null) return null;
    for (final d in _diseaseList) {
      if (d['id']?.toString() == id) {
        return (d['diseaseName'] ?? d['disease_name'])?.toString();
      }
    }
    return null;
  }

  String? _agrochemicalNameById(String? id) {
    if (id == null) return null;
    for (final a in _agrochemicalList) {
      final aId = (a['uuid'] ?? a['id'] ?? '').toString();
      if (aId == id) {
        return (a['name'] ?? a['agrochemical_name'] ?? a['agrochemicalName'])
            ?.toString();
      }
    }
    return null;
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

// Replace the _buildActiveFilters method with this enhanced version:
Widget _buildActiveFilters() {
  final chips = <Widget>[];

  if (_selectedSpecies != null && _selectedSpecies!.isNotEmpty) {
    chips.add(
      _buildFilterChip(
        'Species: ${_selectedSpecies!}',
        () {
          _speciesFilterController.clear();
          _applyFilters(
            species: null,
            plantingFrom: _currentPlantingFrom,
            plantingTo: _currentPlantingTo,
            diseaseId: _selectedDiseaseId,
            agrochemicalId: _selectedAgrochemicalId,
          );
        },
      ),
    );
  }

  if (_selectedDiseaseId != null && _selectedDiseaseId!.isNotEmpty) {
    final diseaseName = _diseaseNameById(_selectedDiseaseId) ?? _selectedDiseaseId;
    chips.add(
      _buildFilterChip(
        'Disease: $diseaseName',
        () {
          _diseaseFilterController.clear();
          _applyFilters(
            species: _selectedSpecies,
            plantingFrom: _currentPlantingFrom,
            plantingTo: _currentPlantingTo,
            diseaseId: null,
            agrochemicalId: _selectedAgrochemicalId,
          );
        },
      ),
    );
  }

  if (_selectedAgrochemicalId != null && _selectedAgrochemicalId!.isNotEmpty) {
    final agroName =
        _agrochemicalNameById(_selectedAgrochemicalId) ?? _selectedAgrochemicalId;
    chips.add(
      _buildFilterChip(
        'Agrochemical: $agroName',
        () {
          _agrochemicalFilterController.clear();
          _applyFilters(
            species: _selectedSpecies,
            plantingFrom: _currentPlantingFrom,
            plantingTo: _currentPlantingTo,
            diseaseId: _selectedDiseaseId,
            agrochemicalId: null,
          );
        },
      ),
    );
  }

  if ((_currentPlantingFrom.isNotEmpty) || (_currentPlantingTo.isNotEmpty)) {
    String label;
    if (_currentPlantingFrom.isNotEmpty && _currentPlantingTo.isNotEmpty) {
      label = 'Planted: ${_currentPlantingFrom} to ${_currentPlantingTo}';
    } else if (_currentPlantingFrom.isNotEmpty) {
      label = 'Planted >= ${_currentPlantingFrom}';
    } else {
      label = 'Planted <= ${_currentPlantingTo}';
    }

    chips.add(
      _buildFilterChip(
        label,
        () {
          _applyFilters(
            species: _selectedSpecies,
            plantingFrom: '',
            plantingTo: '',
            diseaseId: _selectedDiseaseId,
            agrochemicalId: _selectedAgrochemicalId,
          );
        },
      ),
    );
  }

  if (chips.isEmpty) return const SizedBox.shrink();

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PersistentAppBar(
        title: 'Trees',
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (context) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 10,
                        bottom: 0,
                      ),
                      leading: const Icon(Icons.lock),
                      title: const Text('Change Password'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) =>
                                    const ResetPasswordPage(fromSettings: true),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 0,
                        bottom: 20,
                      ),
                      leading: const Icon(Icons.logout),
                      title: const Text('Logout'),
                      onTap: () async {
                        final shouldLogout = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Confirm Logout'),
                                content: const Text(
                                  'Are you sure you want to logout?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(true),
                                    child: const Text('Logout'),
                                  ),
                                ],
                              ),
                        );

                        if (shouldLogout == true) {
                          try {
                            final ok = await AuthService.logout();

                            if (ok) {
                              await Flushbar(
                                message: 'Logged out',
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                ),
                                backgroundColor: Colors.green.shade700,
                                duration: const Duration(seconds: 2),
                                borderRadius: BorderRadius.circular(8),
                                margin: const EdgeInsets.all(12),
                              ).show(context);
                            } else {
                              await Flushbar(
                                message: 'Logging out',
                                icon: const Icon(
                                  Icons.info,
                                  color: Colors.white,
                                ),
                                backgroundColor: Colors.orange.shade700,
                                duration: const Duration(seconds: 2),
                                borderRadius: BorderRadius.circular(8),
                                margin: const EdgeInsets.all(12),
                              ).show(context);
                            }

                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => LoginPage()),
                              (route) => false,
                            );
                          } catch (e) {
                            await Flushbar(
                              message: 'Logout failed: $e',
                              icon: const Icon(
                                Icons.error,
                                color: Colors.white,
                              ),
                              backgroundColor: Colors.red.shade700,
                              duration: const Duration(seconds: 3),
                              borderRadius: BorderRadius.circular(8),
                              margin: const EdgeInsets.all(12),
                            ).show(context);
                          }
                        }
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildSearchBar(context),
            const SizedBox(height: 8),
            _buildActiveFilters(),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _currentPage = 1;
                  await fetchTrees(page: 1);
                },
                child: _isInitialLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.hunterGreen,
                        ),
                      )
                    : _filteredTrees.isEmpty
                        ? Center(
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
                                    _hasActiveFilters()
                                        ? 'No trees found'
                                        : 'No trees yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.gray600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _hasActiveFilters()
                                        ? 'Try adjusting your filters or search'
                                        : 'Create your first tree to get started',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.gray500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount:
                              _filteredTrees.length +
                              1, // +1 for loading indicator
                          itemBuilder: (context, index) {
                            if (index < _filteredTrees.length) {
                              final tree = _filteredTrees[index];
                              return _buildTreeCard(context, tree: tree);
                            } else if (_isLoadingMore) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            } else {
                              return const SizedBox.shrink(); // empty at the end
                            }
                          },
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.location_on,
                  color: AppColors.danger,
                  size: 30,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MapPage()),
                  );
                },
              ),
              const SizedBox(width: 5),
              Expanded(
                child: TextField(
                  onChanged: (value) {
                    filterTrees(value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search Tree',
                    hintStyle: TextStyle(color: AppColors.gray600, fontSize: 12),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: GestureDetector(
                      onTap: _isOnline ? () => _showSpeciesFilterDialog(context) : null,
                      child: Icon(
                        Icons.filter_alt_outlined,
                        color: _isOnline ? null : AppColors.gray400,
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
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateTreePage()),
                  );
                  await _handleNavigationResult(result);
                },
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.pakistanGreen,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTreeCard(
    BuildContext context, {
    required Map<String, dynamic> tree, // ✅ Accept tree map
  }) {
    final String tag = tree['tree_tag'] ?? 'Tree';
    // Sync status handling temporarily disabled in UI while debugging sync issues.
    // Format planted date uniformly
    final String rawDate = tree['planted_at']?.toString() ?? '';
    String displayDate = rawDate;
    if (rawDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDate);
        displayDate = DateFormat('yyyy-MM-dd').format(dt);
      } catch (_) {
        // fallback: strip time portion if present
        if (rawDate.contains('T')) {
          displayDate = rawDate.split('T').first;
        }
      }
    }
    final String type = tree['species']?['name'] ?? 'Unknown Species';
    final String uuid = tree['uuid']?.toString() ?? tree['id']?.toString() ?? 'pending';

    // Color statusColor =
    //     status == 'Flowering' ? AppColors.successLight : AppColors.dangerLight;
    // Color statusTextColor =
    //     status == 'Flowering'
    //         ? AppColors.successActive
    //         : AppColors.dangerActive;

    final bool isUnsynced =
        (tree['synced'] == 0 || tree['synced']?.toString() == '0');
    return Card(
      color: isUnsynced ? AppColors.warningLight : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUnsynced ? AppColors.warningActive : AppColors.gray400,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // QR Code
            SizedBox(
              width: 70,
              height: 70,
              child: QrImageView(data: uuid, version: QrVersions.auto),
            ),
            const SizedBox(width: 10),
            // Tree info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tag,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        type,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // NOTE: Temporarily hiding the Unsynced badge while tree sync
                      // is being debugged. Re-enable by restoring the conditional
                      // `if (synced == 0)` block when tree sync is fixed.
                      const Text(
                        "•",
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        displayDate,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // View Button (green background, white text)
            ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => TreeDetailsPage(treeID: (tree['uuid'] ?? tree['id'] ?? '').toString()),
                  ),
                );

                // Reload tree list when returning from tree details
                if (result != null) {
                  _currentPage = 1;
                  await fetchTrees(page: 1);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mossGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(60, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text("View"),
            ),
          ],
        ),
      ),
    );
  }
}
