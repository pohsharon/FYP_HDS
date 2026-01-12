import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/fruit/create_fruit.dart';
import 'package:fyp_hbs/services/api/fruit_api.dart';
import 'package:fyp_hbs/services/api/tree_api.dart';
import 'package:fyp_hbs/models/fruit_model.dart';
import 'package:fyp_hbs/models/tree_model.dart';
import 'package:fyp_hbs/tree/tree_details.dart';
import 'package:fyp_hbs/services/local database/fruit_db.dart';
import 'package:fyp_hbs/services/local database/tree_db.dart';
import 'package:fyp_hbs/services/local database/species_db.dart';
import 'package:fyp_hbs/services/local database/harvest_db.dart';
import 'package:fyp_hbs/widgets/persistent_appbar.dart';
import 'package:intl/intl.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:fyp_hbs/services/api/auth_service.dart';
import 'package:fyp_hbs/authentication/reset_password.dart';
import 'package:fyp_hbs/authentication/login.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fyp_hbs/services/app_initializer.dart';

const String _productBaseUrl = 'https://app-hosbaduriansystem-dev-001-g5dwg4gpeqbfgqgy.southeastasia-01.azurewebsites.net/product-details';

String _getProductQrUrl(String uuid) => '$_productBaseUrl/$uuid';

class FruitPage extends StatefulWidget {
  const FruitPage({super.key, this.scannedFruitUuid, this.fromQR = false});
  
  final String? scannedFruitUuid;
  final bool fromQR;

  @override
  State<FruitPage> createState() => _FruitPageState();
}

class FruitListFromQR extends StatefulWidget {
  const FruitListFromQR({super.key, required this.fruitUuid});
  
  final String fruitUuid;

  @override
  State<FruitListFromQR> createState() => _FruitListFromQRState();
}

class _FruitListFromQRState extends State<FruitListFromQR> {
  @override
  void initState() {
    super.initState();
    // Navigate to FruitPage with scanned UUID and fromQR flag
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => FruitPage(scannedFruitUuid: widget.fruitUuid, fromQR: true),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _FruitPageState extends State<FruitPage> {
  List<Map<String, dynamic>> _allFruits = [];
  List<Map<String, dynamic>> _filteredFruits = [];
  List<String> _speciesList = [];
  String? _selectedSpecies;
  final TextEditingController _speciesFilterController =
      TextEditingController();
  // Persistent fruit filter state
  String? _currentGrade;
  final TextEditingController _gradeController = TextEditingController();
  final TextEditingController _harvestFromController = TextEditingController();
  final TextEditingController _harvestToController = TextEditingController();
  final TextEditingController _weightMinController = TextEditingController();
  final TextEditingController _weightMaxController = TextEditingController();
  bool _isInitialLoading = true;
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool _hasActiveFilters() {
    return _selectedSpecies != null ||
        _currentGrade != null ||
        _harvestFromController.text.isNotEmpty ||
        _harvestToController.text.isNotEmpty ||
        _weightMinController.text.isNotEmpty ||
        _weightMaxController.text.isNotEmpty ||
        (_selectedHarvestUuid != null &&
            _activeHarvestEvent != null &&
            _selectedHarvestUuid !=
                (_activeHarvestEvent?['uuid']?.toString() ?? ''));
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    AppInitializer.syncCompleted.removeListener(_onSyncCompleted);
    _speciesFilterController.dispose();
    _gradeController.dispose();
    _harvestFromController.dispose();
    _harvestToController.dispose();
    _weightMinController.dispose();
    _weightMaxController.dispose();
    _harvestEventController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _harvestEvents = [];
  Map<String, dynamic>? _activeHarvestEvent;
  String? _selectedHarvestUuid;
  final TextEditingController _harvestEventController = TextEditingController();

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString();
    if (s.isEmpty || s == 'null') return null;
    return DateTime.tryParse(s);
  }

  Map<String, dynamic>? _findLatestActiveEvent(
    List<Map<String, dynamic>> events,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Map<String, dynamic>? candidate;
    DateTime? candidateStart;

    for (final ev in events) {
      final startDt = _parseDate(ev['start_date'] ?? ev['start']);
      if (startDt == null) continue;
      final start = DateTime(startDt.year, startDt.month, startDt.day);
      final endDt = _parseDate(ev['end_date'] ?? ev['end']);

      // Only consider events with NO end date (ongoing/active events)
      if (endDt != null) continue;

      // Must have started already
      if (today.isBefore(start)) continue;

      if (candidate == null) {
        candidate = ev;
        candidateStart = start;
        continue;
      }

      if (candidateStart != null && start.isAfter(candidateStart)) {
        candidate = ev;
        candidateStart = start;
      }
    }

    return candidate;
  }

  String _eventLabel(Map<String, dynamic> ev) {
    final name =
        (ev['event_name'] ?? ev['name'] ?? ev['title'] ?? 'Harvest Event')
            .toString();
    final start = _parseDate(ev['start_date'] ?? ev['start']);
    final end = _parseDate(ev['end_date'] ?? ev['end']);

    if (start == null) return name;
    final today = DateTime.now();
    final fmt = DateFormat('MMM dd');
    final startStr = fmt.format(start);

    // No end date -> mark active if started, otherwise upcoming
    if (end == null) {
      if (!today.isBefore(start)) {
        return '$name • $startStr (Active)';
      }
      return '$name • starts $startStr';
    }

    final endStr = fmt.format(end);

    // If same month, show: "Event Name • Jan 15-20"
    if (start.month == end.month) {
      return '$name • ${DateFormat('MMM').format(start)} ${start.day}-${end.day}';
    }

    // Different months: "Event Name • Jan 15 - Feb 20"
    return '$name • $startStr - $endStr';
  }

  bool get _canCreateFruit {
    if (_activeHarvestEvent == null) return false;
    final activeUuid = _activeHarvestEvent?['uuid']?.toString() ?? '';
    return _selectedHarvestUuid == activeUuid;
  }

  @override
  @override
  void initState() {
    super.initState();
    _loadHarvestEvents();
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
    
    // If a fruit UUID was scanned, show its details after loading completes
    if (widget.scannedFruitUuid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showScannedFruitDetails(widget.scannedFruitUuid!);
      });
    }
  }

  void _onSyncCompleted() {
    if (mounted) {
      _loadHarvestEvents();
    }
  }

  Future<void> _showScannedFruitDetails(String fruitUuid) async {
    // Wait for the harvest events to load
    int attempts = 0;
    while (_isInitialLoading && attempts < 30) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
    
    // Find the fruit in the current list by either 'uuid' or checking both possible keys
    Map<String, dynamic> fruit = <String, dynamic>{};
    
    for (final f in _filteredFruits) {
      final fruitId = f['uuid'] ?? f['harvest_uuid'] ?? '';
      if (fruitId == fruitUuid) {
        fruit = f;
        break;
      }
    }
    
    // If not found in filtered, try all fruits
    if (fruit.isEmpty) {
      for (final f in _allFruits) {
        final fruitId = f['uuid'] ?? f['harvest_uuid'] ?? '';
        if (fruitId == fruitUuid) {
          fruit = f;
          break;
        }
      }
    }
    
    // If still not found, check local database (for offline support)
    if (fruit.isEmpty) {
      try {
        final localFruits = await FruitDB().getAllFruits();
        for (final localFruit in localFruits) {
          if (localFruit.harvest_uuid == fruitUuid) {
            // Convert FruitModel to map format matching the UI expectation
            final speciesRows = await SpeciesDB().getAllSpecies();
            final Map<String, String> speciesLookup = {};
            for (final s in speciesRows) {
              final key = s['id']?.toString();
              final name = s['name']?.toString() ?? '';
              if (key != null) speciesLookup[key] = name;
            }

            final localTrees = await TreeDB().fetchAllTrees();
            final Map<String, TreeModel> treeByUuid = {};
            for (final t in localTrees) {
              treeByUuid[t.uuid] = t;
            }

            final treeUuid = localFruit.tree_uuid;
            String speciesName = 'Unknown Species';
            String treeTag = 'Offline Tree';
            if (treeUuid != null && treeByUuid.containsKey(treeUuid)) {
              final tm = treeByUuid[treeUuid]!;
              final sid = tm.speciesId?.toString();
              if (sid != null && speciesLookup.containsKey(sid)) {
                speciesName = speciesLookup[sid]!;
              }
              treeTag = tm.treeTag ?? treeTag;
            }

            String fruitTag = (localFruit.fruit_tag != null && localFruit.fruit_tag!.isNotEmpty)
                ? localFruit.fruit_tag!
                : 'Offline Fruit';

            fruit = {
              'uuid': localFruit.harvest_uuid ?? '',
              'fruit_tag': fruitTag,
              'harvested_at': localFruit.harvested_at ?? '',
              'weight': localFruit.weight,
              'grade': localFruit.grade ?? '',
              'synced': localFruit.synced,
              'pendingUpdate': localFruit.pendingUpdate,
              'pendingDelete': localFruit.pendingDelete,
              'tree': {
                'uuid': treeUuid ?? '',
                'tree_tag': treeTag,
                'species': {'name': speciesName},
              },
            };
            break;
          }
        }
      } catch (e) {
        debugPrint('Error checking local database for fruit: $e');
      }
    }
    
    if (fruit.isNotEmpty && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _showFruitDetailsDialog(context, fruit);
      }
    } else {
      debugPrint('Fruit not found: $fruitUuid');
      debugPrint('Filtered fruits count: ${_filteredFruits.length}');
      debugPrint('All fruits count: ${_allFruits.length}');
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

  Future<void> _loadHarvestEvents() async {
    if (mounted) {
      setState(() {
        _isInitialLoading = true;
      });
    }

    List<Map<String, dynamic>> events = [];

    try {
      events = await TreeApi.fetchEvents();
      if (events.isNotEmpty) {
        try {
          await HarvestDB().cacheRemoteHarvestEvents(events);
        } catch (_) {}
      }
    } catch (e) {
      try {
        events = await HarvestDB().getAllHarvestEvents();
      } catch (_) {}
    }

    if (events.isNotEmpty) {
      events.sort((a, b) {
        final aStart = _parseDate(a['start_date'] ?? a['start']);
        final bStart = _parseDate(b['start_date'] ?? b['start']);
        if (aStart == null && bStart == null) return 0;
        if (aStart == null) return 1;
        if (bStart == null) return -1;
        return bStart.compareTo(aStart);
      });
    }

    final active = _findLatestActiveEvent(events);

    final targetUuid =
        _selectedHarvestUuid ?? active?['uuid']?.toString() ?? ''; // may be ''

    if (mounted) {
      setState(() {
        _harvestEvents = events;
        _activeHarvestEvent = active;
        _selectedHarvestUuid = targetUuid.isEmpty ? null : targetUuid;
      });
    }

    await fetchFruits(
      harvestUuid: targetUuid.isEmpty ? null : targetUuid,
      skipLoadingFlag: true,
    );

    if (mounted) {
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _changeHarvestEvent(String? harvestUuid) async {
    final target = harvestUuid ?? _activeHarvestEvent?['uuid']?.toString();
    await fetchFruits(harvestUuid: target);
  }

  Future<void> fetchFruits({
    String? harvestUuid,
    bool skipLoadingFlag = false,
  }) async {
    if (!skipLoadingFlag && mounted) {
      setState(() {
        _isInitialLoading = true;
      });
    }

    final targetUuid =
        harvestUuid ?? _selectedHarvestUuid ?? _activeHarvestEvent?['uuid'];
    final targetUuidStr =
        targetUuid != null && targetUuid.toString().isNotEmpty
            ? targetUuid.toString()
            : null;
    final useEventScopedEndpoint = targetUuidStr != null;

    try {
      final fruits =
          useEventScopedEndpoint
            ? await FruitApi.fetchFruitsByHarvestUuid(targetUuidStr)
              : await FruitApi.fetchFruits();

      final speciesSet = <String>{};
      for (var fruit in fruits) {
        final speciesName =
            fruit['tree']?['species']?['name'] ?? 'Unknown Species';
        speciesSet.add(speciesName);
      }

      if (mounted) {
        setState(() {
          _selectedHarvestUuid = targetUuidStr;
          _allFruits = fruits;
          _filteredFruits = fruits;
          _speciesList = speciesSet.toList();
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      // On error (likely offline), try to load fruits from local DB cache
      await _checkOnline();
      try {
        var localFruits = await FruitDB().getAllFruits();
        List<FruitModel> scopedFruits = localFruits;
        if (useEventScopedEndpoint) {
          scopedFruits =
              localFruits
                  .where((f) => f.harvest_uuid?.toString() == targetUuidStr)
                  .toList();
          // If nothing or very few match the selected harvest event offline, fall back to all cached fruits
          if (scopedFruits.isEmpty || scopedFruits.length < localFruits.length) {
            scopedFruits = localFruits;
          }
        }

        // build tree/species lookup to populate nested fields similar to API shape
        final localTrees = await TreeDB().fetchAllTrees();
        final speciesRows = await SpeciesDB().getAllSpecies();
        final Map<String, String> speciesLookup = {};
        for (final s in speciesRows) {
          final key = s['id']?.toString();
          final name = s['name']?.toString() ?? '';
          if (key != null) speciesLookup[key] = name;
        }

        final Map<String, TreeModel> treeByUuid = {};
        for (final t in localTrees) {
          treeByUuid[t.uuid] = t;
        }

        final mapped =
          scopedFruits.map((f) {
              final treeUuid = f.tree_uuid;
              String speciesName = 'Unknown Species';
              String treeTag = 'Offline Tree';
              if (treeUuid != null && treeByUuid.containsKey(treeUuid)) {
                final tm = treeByUuid[treeUuid]!;
                final sid = tm.speciesId?.toString();
                if (sid != null && speciesLookup.containsKey(sid)) {
                  speciesName = speciesLookup[sid]!;
                } else if (tm.speciesId != null) {
                  speciesName = tm.speciesId.toString();
                }
                treeTag = tm.treeTag ?? treeTag;
              }

              // Prefer an explicit persisted fruit_tag if available, otherwise fall
              // back to harvested date or short harvest uuid for readability.
              // Never use grade as the primary title.
              String fruitTag =
                  (f.fruit_tag != null && f.fruit_tag!.isNotEmpty)
                      ? f.fruit_tag!
                      : (() {
                        if (f.harvested_at != null &&
                            f.harvested_at!.isNotEmpty) {
                          return f.harvested_at!;
                        } else if (f.harvest_uuid != null &&
                            f.harvest_uuid!.isNotEmpty) {
                          final id = f.harvest_uuid!;
                          return id.length > 8 ? id.substring(0, 8) : id;
                        } else {
                          return 'Offline Fruit';
                        }
                      })();

              return {
                'uuid': f.harvest_uuid ?? '',
                'fruit_tag': fruitTag,
                'harvested_at': f.harvested_at ?? '',
                'weight': f.weight,
                'grade': f.grade ?? '',
                'synced': f.synced,
                'pendingUpdate': f.pendingUpdate,
                'pendingDelete': f.pendingDelete,
                'tree': {
                  'uuid': treeUuid ?? '',
                  'tree_tag': treeTag,
                  'species': {'name': speciesName},
                },
              };
            }).toList();

        final mappedList = mapped.cast<Map<String, dynamic>>().toList();

        if (mounted) {
          setState(() {
            _selectedHarvestUuid = targetUuidStr;
            _allFruits = mappedList;
            _filteredFruits = mappedList;
            _speciesList =
                mappedList
                    .map(
                      (e) =>
                          (e['tree']
                                  as Map<String, dynamic>?)?['species']?['name']
                              ?.toString() ??
                          'Unknown',
                    )
                    .toSet()
                    .toList();
            _isInitialLoading = false;
          });
        }
      } catch (e2) {
        if (mounted) {
          setState(() {
            _isInitialLoading = false;
          });
        }
        if (mounted) {
          await Flushbar(
            message: "Error loading fruits: $e",
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(12),
            borderRadius: BorderRadius.circular(8),
          ).show(context);
        }
      }
    }
  }

  void filterFruits(String query) {
    final filtered =
        _allFruits.where((fruit) {
          final fruitTag = fruit['fruit_tag']?.toString().toLowerCase() ?? '';
          return fruitTag.contains(query.toLowerCase());
        }).toList();
    if (mounted) {
      setState(() {
        _filteredFruits = filtered;
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
          child: Icon(icon, size: 16, color: AppColors.hunterGreen),
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
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
    required DateTime minDate,
    required DateTime maxDate,
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
          labelStyle: TextStyle(color: AppColors.gray600, fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: AppColors.hunterGreen),
          suffixIcon:
              controller.text.isNotEmpty
                  ? IconButton(
                    icon: Icon(Icons.clear, size: 18, color: AppColors.gray600),
                    onPressed: () {
                      setStateDialog(() => controller.clear());
                    },
                  )
                  : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
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
            initialDate: DateTime.now().isAfter(maxDate) ? maxDate : DateTime.now(),
            firstDate: minDate,
            lastDate: maxDate,
          );
          if (picked != null) {
            setStateDialog(
              () => controller.text = DateFormat('dd/MM/yyyy').format(picked),
            );
          }
        },
      ),
    );
  }

  // ignore: unused_element
  Widget _buildCompactField(
    TextEditingController controller,
    String hint,
    String unit,
  ) {
    return TextField(
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

  void _applyFruitFilters({
    String? species,
    String? grade,
    String? harvestFrom,
    String? harvestTo,
    String? weightMin,
    String? weightMax,
  }) {
    List<Map<String, dynamic>> working = List<Map<String, dynamic>>.from(
      _allFruits,
    );

    if (species != null && species.isNotEmpty) {
      working =
          working
              .where(
                (f) =>
                    (f['tree']?['species']?['name']?.toString() ?? '') ==
                    species,
              )
              .toList();
    }

    if (grade != null && grade.isNotEmpty) {
      working =
          working
              .where((f) => (f['grade']?.toString() ?? '') == grade)
              .toList();
    }

    DateTime? parseDate(String? s) {
      if (s == null || s.trim().isEmpty) return null;
      // Support both dd/MM/yyyy and yyyy-MM-dd formats
      try {
        return DateFormat('dd/MM/yyyy').parse(s);
      } catch (_) {
        return DateTime.tryParse(s);
      }
    }

    final from = parseDate(harvestFrom);
    final to = parseDate(harvestTo);
    if (from != null || to != null) {
      working =
          working.where((f) {
            final s = f['harvested_at']?.toString() ?? '';
            final dt = DateTime.tryParse(s);
            if (dt == null) return false;
            // Compare dates only (ignore time)
            final dtDateOnly = DateTime(dt.year, dt.month, dt.day);
            if (from != null) {
              final fromDateOnly = DateTime(from.year, from.month, from.day);
              if (dtDateOnly.isBefore(fromDateOnly)) return false;
            }
            if (to != null) {
              // Include entire end date
              final toDateOnly = DateTime(to.year, to.month, to.day);
              if (dtDateOnly.isAfter(toDateOnly)) return false;
            }
            return true;
          }).toList();
    }

    double? parseDouble(String? s) {
      if (s == null || s.trim().isEmpty) return null;
      return double.tryParse(s.trim());
    }

    final wMin = parseDouble(weightMin);
    final wMax = parseDouble(weightMax);
    if (wMin != null || wMax != null) {
      working =
          working.where((f) {
            final v = f['weight'];
            if (v == null) return false;
            final dv =
                (v is num)
                    ? v.toDouble()
                    : double.tryParse(v.toString()) ?? double.nan;
            if (dv.isNaN) return false;
            if (wMin != null && dv < wMin) return false;
            if (wMax != null && dv > wMax) return false;
            return true;
          }).toList();
    }

    if (mounted) {
      setState(() {
        _selectedSpecies =
            (species == null || species.isEmpty) ? null : species;
        _currentGrade = (grade == null || grade.isEmpty) ? null : grade;
        _harvestFromController.text = harvestFrom ?? '';
        _harvestToController.text = harvestTo ?? '';
        _weightMinController.text = weightMin ?? '';
        _weightMaxController.text = weightMax ?? '';
        _filteredFruits = working;
      });
    }
  }

  Future<void> _resetAllFiltersAndEvent() async {
    _speciesFilterController.clear();
    _gradeController.clear();
    _harvestFromController.clear();
    _harvestToController.clear();
    _weightMinController.clear();
    _weightMaxController.clear();

    if (_activeHarvestEvent != null) {
      await _changeHarvestEvent(_activeHarvestEvent?['uuid']?.toString());
    } else {
      await fetchFruits(harvestUuid: _selectedHarvestUuid);
    }

    if (mounted) {
      setState(() {
        _selectedSpecies = null;
        _currentGrade = null;
        _filteredFruits = _allFruits;
      });
    }
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
                Icon(Icons.filter_alt, size: 16, color: AppColors.hunterGreen),
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
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilters() {
    final chips = <Widget>[];

    if (_selectedHarvestUuid != null &&
        _activeHarvestEvent != null &&
        _selectedHarvestUuid != _activeHarvestEvent?['uuid']?.toString()) {
      final ev = _harvestEvents.firstWhere(
        (e) => (e['uuid'] ?? e['id'])?.toString() == _selectedHarvestUuid,
        orElse: () => {},
      );
      final label = ev.isNotEmpty ? _eventLabel(ev) : 'Selected harvest event';
      chips.add(
        _buildFilterChip('Event: $label', () {
          _changeHarvestEvent(_activeHarvestEvent?['uuid']?.toString());
          _applyFruitFilters(
            species: _selectedSpecies,
            grade: _currentGrade,
            harvestFrom: _harvestFromController.text,
            harvestTo: _harvestToController.text,
            weightMin: _weightMinController.text,
            weightMax: _weightMaxController.text,
          );
        }),
      );
    }

    if (_selectedSpecies != null && _selectedSpecies!.isNotEmpty) {
      chips.add(
        _buildFilterChip('Species: ${_selectedSpecies!}', () {
          _speciesFilterController.clear();
          _applyFruitFilters(
            species: null,
            grade: _currentGrade,
            harvestFrom: _harvestFromController.text,
            harvestTo: _harvestToController.text,
            weightMin: _weightMinController.text,
            weightMax: _weightMaxController.text,
          );
        }),
      );
    }

    if (_currentGrade != null && _currentGrade!.isNotEmpty) {
      chips.add(
        _buildFilterChip('Grade: ${_currentGrade!}', () {
          _gradeController.clear();
          _applyFruitFilters(
            species: _selectedSpecies,
            grade: null,
            harvestFrom: _harvestFromController.text,
            harvestTo: _harvestToController.text,
            weightMin: _weightMinController.text,
            weightMax: _weightMaxController.text,
          );
        }),
      );
    }

    if (_harvestFromController.text.isNotEmpty ||
        _harvestToController.text.isNotEmpty) {
      String label;
      if (_harvestFromController.text.isNotEmpty &&
          _harvestToController.text.isNotEmpty) {
        label =
            'Harvest: ${_harvestFromController.text} to ${_harvestToController.text}';
      } else if (_harvestFromController.text.isNotEmpty) {
        label = 'Harvest >= ${_harvestFromController.text}';
      } else {
        label = 'Harvest <= ${_harvestToController.text}';
      }

      chips.add(
        _buildFilterChip(label, () {
          _applyFruitFilters(
            species: _selectedSpecies,
            grade: _currentGrade,
            harvestFrom: '',
            harvestTo: '',
            weightMin: _weightMinController.text,
            weightMax: _weightMaxController.text,
          );
        }),
      );
    }

    if (_weightMinController.text.isNotEmpty ||
        _weightMaxController.text.isNotEmpty) {
      String label;
      if (_weightMinController.text.isNotEmpty &&
          _weightMaxController.text.isNotEmpty) {
        label =
            'Weight: ${_weightMinController.text} to ${_weightMaxController.text} kg';
      } else if (_weightMinController.text.isNotEmpty) {
        label = 'Weight >= ${_weightMinController.text} kg';
      } else {
        label = 'Weight <= ${_weightMaxController.text} kg';
      }

      chips.add(
        _buildFilterChip(label, () {
          _applyFruitFilters(
            species: _selectedSpecies,
            grade: _currentGrade,
            harvestFrom: _harvestFromController.text,
            harvestTo: _harvestToController.text,
            weightMin: '',
            weightMax: '',
          );
        }),
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
          Icon(Icons.filter_list, size: 18, color: AppColors.gray600),
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
                children:
                    chips.map((chip) {
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

  void _showSpeciesFilterDialog(BuildContext context) {
    if (!_isOnline) {
      // ignore: avoid_print
      print('Filters disabled offline');
      return;
    }
    String? tempSelectedSpecies = _selectedSpecies;
    String? tempGrade = _currentGrade;
    String? tempHarvestUuid =
        _selectedHarvestUuid ?? _activeHarvestEvent?['uuid']?.toString();

    _speciesFilterController.text = tempSelectedSpecies ?? '';
    _gradeController.text = tempGrade ?? '';
    if (tempHarvestUuid != null) {
      final ev = _harvestEvents.firstWhere(
        (e) => (e['uuid'] ?? e['id'])?.toString() == tempHarvestUuid,
        orElse: () => {},
      );
      if (ev.isNotEmpty) {
        _harvestEventController.text = _eventLabel(ev);
      }
    }

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
                colors: [AppColors.white, AppColors.background],
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
                      colors: [AppColors.hunterGreen, AppColors.mossGreen],
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
                            _buildEnhancedSectionHeader(
                              "Harvest Event",
                              Icons.agriculture,
                            ),
                            const SizedBox(height: 8),
                            _buildEnhancedDropdown(
                              context: context,
                              controller: _harvestEventController,
                              initialSelection: tempHarvestUuid ?? '',
                              entries:
                                  _harvestEvents.isEmpty
                                      ? [
                                        const DropdownMenuEntry(
                                          value: '',
                                          label: 'No events available',
                                        ),
                                      ]
                                      : _harvestEvents
                                          .map<DropdownMenuEntry<String>>(
                                            (ev) => DropdownMenuEntry(
                                              value:
                                                  (ev['uuid'] ?? ev['id'] ?? '')
                                                      .toString(),
                                              label: _eventLabel(ev),
                                            ),
                                          )
                                          .toList(),
                              onSelected: (String? v) {
                                setStateDialog(
                                  () =>
                                      tempHarvestUuid =
                                          (v == null || v.isEmpty) ? null : v,
                                );
                              },
                            ),

                            const SizedBox(height: 20),
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
                            _buildEnhancedSectionHeader(
                              "Harvest Date Range",
                              Icons.date_range,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildEnhancedDateField(
                                    context: context,
                                    controller: _harvestFromController,
                                    label: 'From',
                                    icon: Icons.calendar_today,
                                    setStateDialog: setStateDialog,
                                    minDate: DateTime(2000),
                                    maxDate: DateTime.now(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildEnhancedDateField(
                                    context: context,
                                    controller: _harvestToController,
                                    label: 'To',
                                    icon: Icons.event,
                                    setStateDialog: setStateDialog,
                                    minDate: _harvestFromController.text.isNotEmpty
                                        ? DateTime.tryParse(_harvestFromController.text) ?? DateTime(2000)
                                        : DateTime(2000),
                                    maxDate: DateTime.now(),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),
                            _buildEnhancedSectionHeader("Grade", Icons.grade),
                            const SizedBox(height: 8),
                            _buildEnhancedDropdown(
                              context: context,
                              controller: _gradeController,
                              initialSelection: tempGrade ?? '',
                              entries: [
                                const DropdownMenuEntry(
                                  value: '',
                                  label: 'All grade',
                                ),
                                ...[
                                  'AA',
                                  'A',
                                  'B',
                                  'C',
                                  'D',
                                ].map<DropdownMenuEntry<String>>(
                                  (grade) => DropdownMenuEntry(
                                    value: grade,
                                    label: grade,
                                  ),
                                ),
                              ],
                              onSelected: (String? v) {
                                setStateDialog(() => tempGrade = v);
                              },
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
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _resetAllFiltersAndEvent();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.gray600,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        child: const Text("Reset"),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.hunterGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _changeHarvestEvent(tempHarvestUuid);
                          _applyFruitFilters(
                            species: tempSelectedSpecies,
                            grade: tempGrade,
                            harvestFrom: _harvestFromController.text,
                            harvestTo: _harvestToController.text,
                            weightMin: _weightMinController.text,
                            weightMax: _weightMaxController.text,
                          );
                        },
                        child: const Text("Apply Filters"),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PersistentAppBar(
        title: 'Fruits',
        leading: widget.fromQR
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : IconButton(
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
            if (_isOnline) _buildActiveFilters(),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _changeHarvestEvent(
                    _selectedHarvestUuid ??
                        _activeHarvestEvent?['uuid']?.toString(),
                  );
                  // allow a short delay so UI updates smoothly
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child:
                    _isInitialLoading
                        ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.hunterGreen,
                          ),
                        )
                        : _filteredFruits.isEmpty
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
                                      ? 'No fruits found'
                                      : 'No fruits yet',
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
                                      : 'Create your first fruit to get started',
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredFruits.length,
                          itemBuilder: (context, index) {
                            final fruit = _filteredFruits[index];
                            return _buildFruitCard(context, fruit: fruit);
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
          if (!_isOnline)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange.shade800),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Offline: showing all fruits (filters disabled).',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) {
                    filterFruits(value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search Fruit',
                    hintStyle: TextStyle(color: AppColors.gray600, fontSize: 12),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isOnline
                        ? GestureDetector(
                            onTap: () => _showSpeciesFilterDialog(context),
                            child: const Icon(Icons.filter_alt_outlined),
                          )
                        : Icon(
                            Icons.filter_alt_outlined,
                            color: AppColors.gray400,
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
                  if (!_canCreateFruit) {
                    await Flushbar(
                      message:
                          'New fruits can only be added to the active harvest event.',
                      backgroundColor: Colors.orange.shade700,
                      duration: const Duration(seconds: 2),
                      margin: const EdgeInsets.all(12),
                      borderRadius: BorderRadius.circular(8),
                    ).show(context);
                    return;
                  }
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateFruitPage()),
                  );

                  if (result == true) {
                    await _changeHarvestEvent(
                      _selectedHarvestUuid ??
                          _activeHarvestEvent?['uuid']?.toString(),
                    );
                  }
                },
                child: Opacity(
                  opacity: _canCreateFruit ? 1.0 : 0.4,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.pakistanGreen,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFruitCard(
    BuildContext context, {
    required Map<String, dynamic> fruit,
  }) {
    final String tag = fruit['fruit_tag'] ?? 'Unknown';
    final String species =
        fruit['tree']?['species']?['name'] ?? 'Unknown Species';
    final String weight = fruit['weight']?.toString() ?? 'Unknown';
    final String grade = fruit['grade'] ?? 'Unknown';
    final String uuid = fruit['uuid'];

    final bool isUnsynced = (fruit['synced'] == 0 || 
                             fruit['synced']?.toString() == '0' ||
                             fruit['pendingUpdate'] == 1 ||
                             fruit['pendingDelete'] == 1);

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
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isOnline ? () => _showFruitDetailsDialog(context, fruit) : null,
          child: Row(
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: QrImageView(data: _getProductQrUrl(uuid), version: QrVersions.auto),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 0),
                    Text(
                      species,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    Text(
                      "$weight kg | Grade $grade",
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _isOnline ? () {
                  _showFruitDetailsDialog(context, fruit);
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOnline ? AppColors.mossGreen : AppColors.gray400,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(60, 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  elevation: _isOnline ? 2 : 0,
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
      ),
    );
  }

  void _showFruitDetailsDialog(
  BuildContext context,
  Map<String, dynamic> fruit,
) {
  if (!_isOnline) {
    Flushbar(
      message: 'Cannot edit fruits while offline',
      backgroundColor: Colors.orange.shade700,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(8),
    ).show(context);
    return;
  }
  
  final String uuid = fruit['uuid'] ?? '';
  final String tag = fruit['fruit_tag'] ?? 'Unknown';
  final String date = fruit['harvested_at'] ?? '';
  final String weight = fruit['weight']?.toString() ?? '';
  final String grade = fruit['grade'] ?? '';
  final String species = fruit['tree']?['species']?['name'] ?? '';
  final String treeTag = fruit['tree']?['tree_tag'] ?? '';
  final String? transactionId = fruit['transaction_id'];
  final bool isSpoiled = fruit['is_spoiled'] == true || 
                         fruit['is_spoiled'] == 1 || 
                         fruit['is_spoiled']?.toString() == 'true';

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient background
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.hunterGreen, AppColors.mossGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    const Text(
                      'Fruit Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateFruitPage(fruit: fruit),
                          ),
                        );
                        if (result == true) {
                          await _changeHarvestEvent(
                            _selectedHarvestUuid ??
                                _activeHarvestEvent?['uuid']?.toString(),
                          );
                        }
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // QR Code with card design
                      GestureDetector(
                        onTap: () {
                          if (uuid.isEmpty) return;
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 100,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    QrImageView(
                                      data: _getProductQrUrl(uuid),
                                      version: QrVersions.auto,
                                      size: 300,
                                      gapless: true,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      uuid,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.gray300,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              QrImageView(
                                data: _getProductQrUrl(uuid),
                                version: QrVersions.auto,
                                size: 100,
                                gapless: true,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gray200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  uuid,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.gray600,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),

                      // Fruit Tag
                      Text(
                        tag,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: AppColors.hunterGreen,
                        ),
                      ),
                      // Status badges
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (transactionId != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warningActive,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.hunterGreen.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: AppColors.hunterGreen,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    "Sold",
                                    style: TextStyle(
                                      color: AppColors.hunterGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (transactionId != null && isSpoiled)
                            const SizedBox(width: 8),
                          if (isSpoiled)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 16,
                                    color: Colors.red.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Spoiled",
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Details card
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.gray300,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildEnhancedDetailRow(
                              icon: Icons.calendar_today,
                              label: "Harvest Date",
                              value: date.isNotEmpty 
                                  ? DateFormat('MMM dd, yyyy').format(DateTime.parse(date))
                                  : 'N/A',
                              isFirst: true,
                            ),
                            _buildDivider(),
                            _buildEnhancedDetailRow(
                              icon: Icons.scale,
                              label: "Weight",
                              value: weight.isNotEmpty ? "$weight kg" : 'N/A',
                            ),
                            _buildDivider(),
                            _buildEnhancedDetailRow(
                              icon: Icons.grade,
                              label: "Grade",
                              value: grade.isNotEmpty ? "Grade $grade" : 'N/A',
                            ),
                            _buildDivider(),
                            _buildEnhancedDetailRow(
                              icon: Icons.eco,
                              label: "Species",
                              value: species.isNotEmpty ? species : 'Unknown',
                            ),
                            _buildDivider(),
                            _buildEnhancedDetailRow(
                              icon: Icons.park,
                              label: "Tree Origin",
                              value: treeTag.isNotEmpty ? treeTag : 'Unknown',
                              isLast: true,
                              isClickable: true,
                              onTap: () {
                                Navigator.of(context).pop();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TreeDetailsPage(
                                      treeID: fruit['tree']?['uuid'] ?? '',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildEnhancedDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isFirst = false,
    bool isLast = false,
    bool isClickable = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isClickable ? onTap : null,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(16) : Radius.zero,
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.hunterGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: AppColors.hunterGreen,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isClickable ? AppColors.hunterGreen : AppColors.gray800,
                        decoration: isClickable ? TextDecoration.underline : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (isClickable)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.gray400,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        thickness: 1,
        color: AppColors.gray300,
      ),
    );
  }
}
