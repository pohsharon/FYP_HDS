import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/tree_api.dart';
import 'package:fyp_hbs/services/api/fruit_api.dart';
import 'package:fyp_hbs/repositories/tree_repository.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fyp_hbs/models/fruit_model.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fyp_hbs/services/local database/tree_db.dart';
import 'package:fyp_hbs/services/local database/fruit_db.dart';

class CreateFruitPage extends StatefulWidget {
  final Map<String, dynamic>? fruit;

  const CreateFruitPage({super.key, this.fruit});

  @override
  State<CreateFruitPage> createState() => _CreateFruitPageState();
}
 


class _CreateFruitPageState extends State<CreateFruitPage> {
  final _formKey = GlobalKey<FormState>();

  final weightController = TextEditingController();
  final gradeController = TextEditingController();
  final harvestedAtController = TextEditingController();

  bool isLoading = false;
  bool isSpoiled = false;

  List<Map<String, dynamic>> trees = [];
  String? selectedTreeUuid;

  List<Map<String, dynamic>> events = [];
  String? selectedHarvestUuid;
  String? matchedEventLabel;

  @override
  void initState() {
    super.initState();
    _fetchTrees();
  }

  Future<void> _fetchTrees() async {
  try {
    // Prefer the local DB for UI dropdowns to avoid triggering remote fetches
    List<Map<String, dynamic>> treeList = [];
    try {
      final local = await TreeDB().fetchAllTrees();
      treeList = local
          .map((t) => {'uuid': t.uuid, 'tree_tag': t.treeTag ?? 'Unknown'})
          .toList();
    } catch (e) {
      print('⚠️ _fetchTrees: local DB read failed: $e');
    }

    // If no local trees exist (fresh install), fall back to repository remote fetch
    if (treeList.isEmpty) {
      try {
        final repo = TreeRepository();
        final models = await repo.getTrees();
        treeList = models
            .map((t) => {'uuid': t.uuid, 'tree_tag': t.treeTag ?? 'Unknown'})
            .toList();
      } catch (e) {
        print('⚠️ _fetchTrees: repository remote fetch failed: $e');
      }
    }

    setState(() {
      trees = treeList;
    });

    // If we have trees cached, pre-select the first and load its events
    if (trees.isNotEmpty) {
      selectedTreeUuid ??= trees[0]['uuid'];
      // load events for selected tree (online preferred, falls back to cached)
      _loadEventsForTree(selectedTreeUuid!);
    }
  } catch (e) {
    print(e);
  }
}


  /// Load harvest events for a specific tree. When online, fetch from API and
  /// cache per-tree events in SharedPreferences. When offline, load cached events.
  Future<void> _loadEventsForTree(String treeUuid) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> eventsForTree = [];

    try {
      if (await isOnline()) {
        // ONLINE: fetch the global events list (we need to scan all events to
        // choose the nearest/most relevant event, not just per-tree events).
        final remote = await TreeApi.fetchEvents();
        eventsForTree = List<Map<String, dynamic>>.from(remote);

        try {
          await prefs.setString('harvest_events_all', jsonEncode(eventsForTree));
          print('📦 Cached ${eventsForTree.length} global events');
        } catch (e) {
          print('⚠️ Failed to cache global events: $e');
        }
      } else {
        final raw = prefs.getString('harvest_events_all');
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is List) eventsForTree = List<Map<String, dynamic>>.from(decoded);
        }
      }
    } catch (e) {
      print('⚠️ _loadEventsForTree error: $e — trying global cache');
      final raw = prefs.getString('harvest_events_all');
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) eventsForTree = List<Map<String, dynamic>>.from(decoded);
          print('📦 Loaded ${eventsForTree.length} events from global cache during error fallback');
        } catch (err) {
          print('⚠️ Failed to parse cached global events: $err');
        }
      }
    }

    if (mounted) {
      setState(() {
        events = eventsForTree;
      });

      final now = DateTime.now();
      final nowDate = DateTime(now.year, now.month, now.day);
      for (final ev in eventsForTree) {
        try {
          final startRaw = ev['start_date'] ?? ev['start'] ?? '';
          if (startRaw == null || startRaw.toString().isEmpty) continue;
          final startDt = DateTime.parse(startRaw.toString());
          final start = DateTime(startDt.year, startDt.month, startDt.day);

          final endRaw = ev['end_date'] ?? ev['end'];
          if (endRaw == null || endRaw.toString().isEmpty || endRaw == 'null') {
            if (!nowDate.isBefore(start)) {
              selectedHarvestUuid = ev['uuid'];
              break;
            }
          } else {
            final endDt = DateTime.parse(endRaw.toString());
            final end = DateTime(endDt.year, endDt.month, endDt.day);
            if (!nowDate.isBefore(start) && !nowDate.isAfter(end)) {
              selectedHarvestUuid = ev['uuid'];
              break;
            }
          }
        } catch (_) {}
      }
      // compute matched event label for UI
      if (selectedHarvestUuid != null) {
        final matched = eventsForTree.firstWhere(
            (e) => (e['uuid'] ?? e['id'])?.toString() == selectedHarvestUuid,
            orElse: () => {});
        if (matched.isNotEmpty) {
          matchedEventLabel = (matched['event_name'] ?? matched['name'] ?? matched['title'] ?? matched['event'])?.toString();
        } else {
          matchedEventLabel = null;
        }
      } else {
        matchedEventLabel = null;
      }
    }
  }

  void _updateHarvestEventForDate(DateTime date) {
    final picked = DateTime(date.year, date.month, date.day);
    for (var event in events) {
      try {
        final startRaw = event['start_date'] ?? event['start'] ?? '';
        if (startRaw == null || startRaw.toString().isEmpty) continue;
        final startDt = DateTime.parse(startRaw.toString());
        final start = DateTime(startDt.year, startDt.month, startDt.day);

        final endRaw = event['end_date'] ?? event['end'];
        if (endRaw == null || endRaw.toString().isEmpty || endRaw == 'null') {
          if (!picked.isBefore(start)) {
            setState(() {
              selectedHarvestUuid = event['uuid'];
            });
            return;
          }
        } else {
          final endDt = DateTime.parse(endRaw.toString());
          final end = DateTime(endDt.year, endDt.month, endDt.day);
          if (!picked.isBefore(start) && !picked.isAfter(end)) {
            setState(() {
              selectedHarvestUuid = event['uuid'];
            });
            return;
          }
        }
      } catch (_) {
      }
    }

    setState(() {
      selectedHarvestUuid = null;
    });
  }

  Future<bool> isOnline() async {
  final connectivityResult = await Connectivity().checkConnectivity();
  return connectivityResult != ConnectivityResult.none;
}

Future<void> _saveFruit() async {
  if (!_formKey.currentState!.validate()) return;
  if (selectedTreeUuid == null) {
    Flushbar(
      message: "Please select a tree",
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.red,
    ).show(context);
    return;
  }
  if (selectedHarvestUuid == null) {
    Flushbar(
      message: "No valid harvest event for this date",
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.orange,
    ).show(context);
    return;
  }

  setState(() => isLoading = true);

  // Prepare typed variables below when saving
  try {
    final treeUuid = selectedTreeUuid!;
    final harvestUuid = selectedHarvestUuid!;
    final weight = double.parse(weightController.text);
    final grade = gradeController.text;
    final harvestedAt = harvestedAtController.text;

    final online = await isOnline();
    // Build the FruitModel early so we can fall back to local save if network
    // call fails or we're offline.
    final fruitModel = FruitModel(
      fruit_tag: (grade.isNotEmpty)
          ? 'Grade $grade'
          : (harvestedAt.isNotEmpty)
              ? harvestedAt
              : (harvestUuid.length > 8 ? harvestUuid.substring(0, 8) : harvestUuid),
      harvest_uuid: harvestUuid,
      transaction_uuid: null,
      harvested_at: harvestedAt,
      created_at: DateTime.now().toIso8601String(),
      is_spoiled: isSpoiled,
      tree_uuid: treeUuid,
      weight: weight,
      grade: grade,
      synced: 0,
      pendingUpdate: 0,
      pendingDelete: 0,
    );

    var savedLocally = false;
    if (online) {
      try {
        await FruitApi.createFruit(
          tree_uuid: treeUuid,
          harvest_uuid: harvestUuid,
          weight: weight,
          grade: grade,
          harvested_at: harvestedAt,
          is_spoiled: isSpoiled,
        );
      } catch (e) {
        // Network/server error — fall back to local save so user action is not lost.
        print('⚠️ FruitApi.createFruit failed, saving locally: $e');
        try {
          await FruitDB().insertFruit(fruitModel);
          savedLocally = true;
        } catch (insertErr) {
          print('⚠️ Failed to save fruit locally after API failure: $insertErr');
          // Re-throw original exception so upstream error UI shows it
          rethrow;
        }
      }
    } else {
      // Offline: save locally
      await FruitDB().insertFruit(fruitModel);
      try {
        final unsynced = await FruitDB().getUnsyncedFruits();
        print('🍏 Saved fruit locally (harvest_uuid=${fruitModel.harvest_uuid}). Unsynced count=${unsynced.length}');
      } catch (e) {
        print('⚠️ Could not read unsynced fruits after insert: $e');
      }
      savedLocally = true;
    }

    if (mounted) {
      // Show a confirmation Flushbar and wait for it to dismiss before popping.
      try {
        if (online && !savedLocally) {
          await Flushbar(
            message: widget.fruit == null ? 'Fruit created successfully (online)' : 'Fruit updated successfully (online)',
            icon: const Icon(Icons.check_circle, color: Colors.white),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
            borderRadius: BorderRadius.circular(12),
            margin: const EdgeInsets.all(12),
            flushbarPosition: FlushbarPosition.TOP,
          ).show(context);
        } else {
          final offlineMsg = widget.fruit != null
              ? 'Changes saved locally and will be synced'
              : 'Fruit saved locally';
          await Flushbar(
            message: offlineMsg,
            icon: const Icon(Icons.cloud_off, color: Colors.white),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 2),
            borderRadius: BorderRadius.circular(12),
            margin: const EdgeInsets.all(12),
            flushbarPosition: FlushbarPosition.TOP,
          ).show(context);
        }
      } catch (_) {
        // If Flushbar fails for any reason, still attempt to pop to return to caller
      }
      Navigator.pop(context, true);
    }
  } catch (e) {
    Flushbar(
      message: "Error saving fruit: $e",
      icon: const Icon(Icons.error, color: Colors.white),
      backgroundColor: Colors.red.shade700,
      duration: const Duration(seconds: 3),
      borderRadius: BorderRadius.circular(8),
      margin: const EdgeInsets.all(12),
    ).show(context);
  } finally {
    setState(() => isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.fruit != null ? 'Edit Fruit' : 'Add Fruit',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.pakistanGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Select Tree",
                  filled: true,
                  fillColor: Colors.white,
                ),
                value: selectedTreeUuid,
                items:
                    trees.map((tree) {
                      return DropdownMenuItem<String>(
                        value: tree['uuid'],
                        child: Text(tree['tree_tag'] ?? 'Unknown'),
                      );
                    }).toList(),
                onChanged: (value) async {
                  setState(() {
                    selectedTreeUuid = value;
                    // Clear prior selection when switching tree
                    selectedHarvestUuid = null;
                    events = [];
                  });
                  if (value != null) {
                    await _loadEventsForTree(value);
                  }
                },
                validator:
                    (value) => value == null ? 'Please select a tree' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: harvestedAtController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Harvested Date',
                  suffixIcon: Icon(Icons.calendar_today),
                  filled: true,
                  fillColor: Colors.white,
                ),
                readOnly: true,
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    harvestedAtController.text = DateFormat(
                      'yyyy-MM-dd',
                    ).format(pickedDate);
                    _updateHarvestEventForDate(pickedDate);
                  }
                },
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Pick a date' : null,
              ),
              const SizedBox(height: 8),
              // show matched event / cached count for debugging and UX
              Builder(builder: (context) {
                final count = events.length;
                if (count == 0) return const SizedBox.shrink();
                final label = matchedEventLabel ?? 'No event matched yet';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text('Events cached: $count · Matched: $label', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                );
              }),
              const SizedBox(height: 16),

              TextFormField(
                controller: gradeController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Grade',
                  hintText: 'Enter grade',
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Enter grade' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: weightController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Weight (kg)',
                  hintText: 'Enter weight in kg',
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Enter weight' : null,
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text("Is Spoiled?"),
                value: isSpoiled,
                onChanged: (value) {
                  setState(() {
                    isSpoiled = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: isLoading ? null : _saveFruit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pakistanGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                
                child:
                    isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          'Save',
                          style: TextStyle(color: Colors.white),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
}
}