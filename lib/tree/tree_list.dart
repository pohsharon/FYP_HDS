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
import 'package:fyp_hbs/models/tree_model.dart';
import 'package:intl/intl.dart';
import 'package:fyp_hbs/tree/map.dart';
import 'package:fyp_hbs/authentication/login.dart';
import 'package:fyp_hbs/authentication/reset_password.dart';
import 'package:fyp_hbs/widgets/persistent_appbar.dart';

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
  String? _selectedSpecies;
  final ScrollController _scrollController = ScrollController();
  // Controllers for matching create_tree's DropdownMenu style
  final TextEditingController _speciesFilterController =
      TextEditingController();

  int _currentPage = 1;
  int _lastPage = 1;
  bool _isLoadingMore = false;
  // Persistent filter state so dialog opens with current values
  String _currentFloweringMin = '';
  String _currentFloweringMax = '';
  String _currentHeightMin = '';
  String _currentHeightMax = '';
  String _currentDiameterMin = '';
  String _currentDiameterMax = '';
  // Planting date filter state
  String _currentPlantingFrom = '';
  String _currentPlantingTo = '';
  final TextEditingController _plantingFromController = TextEditingController();
  final TextEditingController _plantingToController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchTrees(page: 1);
    // Populate species dropdown from local DB so the 'All species' list is available offline
    _loadLocalSpecies();

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

  Future<void> _loadLocalSpecies() async {
    try {
      final rows = await SpeciesDB().getAllSpecies();
      final names = <String>[];
      for (final s in rows) {
        final n = s['name']?.toString() ?? '';
        if (n.isNotEmpty) names.add(n);
      }

      setState(() {
        _speciesList.clear();
        _speciesList.addAll(names);
      });
    } catch (e) {
      // Non-fatal: log and continue (dialog will show empty if no species available)
      print('Failed to load local species: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _speciesFilterController.dispose();
    _plantingFromController.dispose();
    _plantingToController.dispose();
    super.dispose();
  }

  Future<void> _loadMoreTrees() async {
    setState(() => _isLoadingMore = true);
    await fetchTrees(page: _currentPage + 1, isLoadMore: true);
    setState(() => _isLoadingMore = false);
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
      });
    }
  }

  Future<void> fetchTrees({int page = 1, bool isLoadMore = false}) async {
    try {
      final response = await TreeApi.fetchTrees(page: page);

      final pagination = response['data'] as Map<String, dynamic>;
      final List<dynamic> treeList = pagination['data'] ?? [];
      final int lastPage = pagination['last_page'] ?? 1;

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

          // Always re-merge & re-sort so offline trees stay on top
          final mergedAll = [..._filteredTrees, ...combined];

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
                'synced': m.synced,
              };
            }).toList();

        if (!mounted) return;

        setState(() {
          _lastPage = 1;
          if (isLoadMore) {
            _filteredTrees.addAll(cleanedLocal);
          } else {
            _filteredTrees = cleanedLocal;
            _allTrees = cleanedLocal;
          }
        });
      } catch (e2) {
        print('Failed to load trees from local DB: $e2');
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

  void _showSpeciesFilterDialog(BuildContext context) {
    // 1. Initial values from existing state
    String? tempSelectedSpecies = _selectedSpecies;
    // Planting date temporary values
    final plantingFrom = TextEditingController(text: _currentPlantingFrom);
    final plantingTo = TextEditingController(text: _currentPlantingTo);

    // 2. Pre-fill controllers with current filter values if they exist
    final floweringMin = TextEditingController(text: _currentFloweringMin);
    final floweringMax = TextEditingController(text: _currentFloweringMax);
    final heightMin = TextEditingController(text: _currentHeightMin);
    final heightMax = TextEditingController(text: _currentHeightMax);
    final diameterMin = TextEditingController(text: _currentDiameterMin);
    final diameterMax = TextEditingController(text: _currentDiameterMax);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: AppColors.background,
          title: Row(
            children: [
              const SizedBox(width: 10),
              const Text(
                "Filter & Sort",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader("Species"),
                      // Match the create_tree DropdownMenu styling and popup width
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final menuWidth = constraints.maxWidth;
                          return SizedBox(
                            width: double.infinity,
                            child: DefaultTextStyle.merge(
                              style: const TextStyle(fontSize: 13),
                              child: DropdownMenu<String>(
                                width: menuWidth,
                                // cap popup height so long lists scroll
                                menuHeight: 300,
                                controller: _speciesFilterController,
                                requestFocusOnTap: true,
                                initialSelection: tempSelectedSpecies ?? '',
                                dropdownMenuEntries: [
                                  const DropdownMenuEntry(
                                    value: '',
                                    label: 'All species',
                                  ),
                                  ..._speciesList
                                      .map<DropdownMenuEntry<String>>(
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
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),
                      _buildSectionHeader("Planting Date (From / To)"),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: plantingFrom,
                              readOnly: true,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'From',
                              ),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null)
                                  setStateDialog(
                                    () =>
                                        plantingFrom.text = DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(picked),
                                  );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: plantingTo,
                              readOnly: true,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'To',
                              ),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null)
                                  setStateDialog(
                                    () =>
                                        plantingTo.text = DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(picked),
                                  );
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      _buildSectionHeader("Range Filters (Min / Max)"),

                      _buildRangeRow(
                        "Flowering",
                        floweringMin,
                        floweringMax,
                        "mo",
                      ),
                      const SizedBox(height: 12),
                      _buildRangeRow("Height", heightMin, heightMax, "cm"),
                      const SizedBox(height: 12),
                      _buildRangeRow(
                        "Diameter",
                        diameterMin,
                        diameterMax,
                        "cm",
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearSpeciesFilter();
              },
              child: Text(
                "Reset",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _applyFilters(
                  species: tempSelectedSpecies,
                  plantingFrom: plantingFrom.text,
                  plantingTo: plantingTo.text,
                  floweringMin: floweringMin.text,
                  floweringMax: floweringMax.text,
                  heightMin: heightMin.text,
                  heightMax: heightMax.text,
                  diameterMin: diameterMin.text,
                  diameterMax: diameterMax.text,
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text("Apply Filters"),
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper: Section Headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  // Helper: Numeric Range Rows
  Widget _buildRangeRow(
    String label,
    TextEditingController min,
    TextEditingController max,
    String unit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: _buildCompactField(min, "Min", unit)),
            const SizedBox(width: 10),
            Expanded(child: _buildCompactField(max, "Max", unit)),
          ],
        ),
      ],
    );
  }

  // Helper: Refined TextFields
  Widget _buildCompactField(
    TextEditingController controller,
    String hint,
    String unit,
  ) {
    return TextField(
      style: const TextStyle(fontSize: 13),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        hintText: hint,
        suffixText: unit,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
    );
  }

  // Sort helper removed — replaced by planting date range fields in the dialog.

  // Apply composite filters and sorting to _allTrees then set _filteredTrees
  void _applyFilters({
    String? species,
    String? plantingFrom,
    String? plantingTo,
    String? floweringMin,
    String? floweringMax,
    String? heightMin,
    String? heightMax,
    String? diameterMin,
    String? diameterMax,
  }) {
    // Start from the full list
    List<dynamic> working = List<dynamic>.from(_allTrees);

    // Species filter
    if (species != null && species.isNotEmpty) {
      working =
          working.where((tree) {
            final name = tree['species']?['name']?.toString() ?? '';
            return name == species;
          }).toList();
    }

    double? parseDouble(String? s) {
      if (s == null || s.trim().isEmpty) return null;
      return double.tryParse(s.trim());
    }

    final fMin = parseDouble(floweringMin);
    final fMax = parseDouble(floweringMax);
    final hMin = parseDouble(heightMin);
    final hMax = parseDouble(heightMax);
    final dMin = parseDouble(diameterMin);
    final dMax = parseDouble(diameterMax);

    // Numeric filtering helpers
    bool inRange(dynamic value, double? min, double? max) {
      if (value == null) return false;
      final v =
          (value is num)
              ? value.toDouble()
              : double.tryParse(value.toString()) ?? double.nan;
      if (v.isNaN) return false;
      if (min != null && v < min) return false;
      if (max != null && v > max) return false;
      return true;
    }

    // Apply flowering filter if any
    if (fMin != null || fMax != null) {
      working =
          working.where((tree) {
            final val =
                tree['flowering_period'] ??
                tree['flowering'] ??
                tree['flowering_period_number'];
            return inRange(val, fMin, fMax);
          }).toList();
    }

    // Height filter
    if (hMin != null || hMax != null) {
      working =
          working.where((tree) {
            final val = tree['height'];
            return inRange(val, hMin, hMax);
          }).toList();
    }

    // Diameter filter
    if (dMin != null || dMax != null) {
      working =
          working.where((tree) {
            final val = tree['diameter'];
            return inRange(val, dMin, dMax);
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
        _currentPlantingFrom = plantingFrom ?? '';
        _currentPlantingTo = plantingTo ?? '';
        _currentFloweringMin = floweringMin ?? '';
        _currentFloweringMax = floweringMax ?? '';
        _currentHeightMin = heightMin ?? '';
        _currentHeightMax = heightMax ?? '';
        _currentDiameterMin = diameterMin ?? '';
        _currentDiameterMax = diameterMax ?? '';
        _filteredTrees = working;
      });
    }
  }

  // Note: species-specific quick filter removed in favour of composite filters

  void _clearSpeciesFilter() {
    if (mounted) {
      setState(() {
        _selectedSpecies = null;
        _currentFloweringMin = '';
        _currentFloweringMax = '';
        _currentHeightMin = '';
        _currentHeightMax = '';
        _currentDiameterMin = '';
        _currentDiameterMax = '';
        _filteredTrees = _allTrees;
      });
    }
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
                                message: 'Logged out (server revoke pending)',
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
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await fetchTrees();
                },
                child:
                    _filteredTrees.isEmpty
                        ? const Center(child: Text("Loading..."))
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
      child: Row(
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
                  onTap: () => _showSpeciesFilterDialog(context),
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
    final String uuid = tree['uuid'];

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

                await _handleNavigationResult(result);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.hunterGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(60, 30),
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
