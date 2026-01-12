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
import 'package:fyp_hbs/services/app_initializer.dart';

class CreateFruitPage extends StatefulWidget {
  final Map<String, dynamic>? fruit;
  final String? prefilledTreeUuid;

  const CreateFruitPage({super.key, this.fruit, this.prefilledTreeUuid});

  @override
  State<CreateFruitPage> createState() => _CreateFruitPageState();
}

class _CreateFruitPageState extends State<CreateFruitPage> {
  final _formKey = GlobalKey<FormState>();

  final weightController = TextEditingController();
  final gradeController = TextEditingController();
  final harvestedAtController = TextEditingController();
  final TextEditingController _treeController = TextEditingController();
  final List<String> _gradeOptions = const ['AA', 'A', 'B', 'C', 'D'];
  String? _selectedGrade;

  bool isLoading = false;
  bool isSpoiled = false;

  List<Map<String, dynamic>> trees = [];
  String? selectedTreeUuid;

  List<Map<String, dynamic>> events = [];
  String? selectedHarvestUuid;
  String? matchedEventLabel;
  DateTime? _matchedEventStartDate;

  @override
  void initState() {
    super.initState();

    if (widget.fruit != null) {
      final f = widget.fruit!;
      weightController.text = f['weight']?.toString() ?? '';
      gradeController.text = f['grade']?.toString() ?? '';
      harvestedAtController.text = f['harvested_at']?.toString() ?? '';
      _selectedGrade = gradeController.text.isNotEmpty
          ? gradeController.text
          : null;
      final spoiled = f['is_spoiled'];
      isSpoiled = (spoiled == true || spoiled == 1 || spoiled?.toString() == 'true');

      selectedTreeUuid = f['tree']?['uuid'] ?? f['tree_uuid'] ?? f['treeId']?.toString();
      selectedHarvestUuid = f['uuid'] ?? f['harvest_uuid'];
    } else if (widget.prefilledTreeUuid != null) {
      // Prefill tree when coming from harvest tab
      selectedTreeUuid = widget.prefilledTreeUuid;
    }

    _fetchTrees().then((_) {
      if (widget.fruit != null && mounted) {
        setState(() {
          selectedHarvestUuid = widget.fruit!['uuid'] ?? widget.fruit!['harvest_uuid'];
        });
      }
    });
  }

  @override
  void dispose() {
    weightController.dispose();
    gradeController.dispose();
    harvestedAtController.dispose();
    _treeController.dispose();
    super.dispose();
  }

  Future<void> _fetchTrees() async {
    try {
      List<Map<String, dynamic>> treeList = [];
      try {
        final local = await TreeDB().fetchAllTrees();
        treeList = local
            .map((t) => {'uuid': t.uuid, 'tree_tag': t.treeTag ?? 'Unknown'})
            .toList();
      } catch (e) {
        print('⚠️ _fetchTrees: local DB read failed: $e');
      }

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

      if (mounted) {
        setState(() {
          trees = treeList;
        });
        _syncTreeController();
      }

      if (trees.isNotEmpty) {
        selectedTreeUuid ??= trees[0]['uuid'];
        _syncTreeController();
        _loadEventsForTree(selectedTreeUuid!);
      }
    } catch (e) {
      print(e);
    }
  }

  void _syncTreeController() {
    if (!mounted) return;
    final match = trees.firstWhere(
      (t) => t['uuid'] == selectedTreeUuid,
      orElse: () => <String, String>{},
    );
    final label = match.isNotEmpty
        ? (match['tree_tag']?.toString() ?? '')
        : '';
    _treeController.text = label;
  }

  Future<void> _loadEventsForTree(String treeUuid) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> eventsForTree = [];

    try {
      if (await isOnline()) {
        final remote = await TreeApi.fetchEvents();
        eventsForTree = List<Map<String, dynamic>>.from(remote);

        try {
          await prefs.setString('harvest_events_all', jsonEncode(eventsForTree));
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
      
      if (selectedHarvestUuid != null) {
        final matched = eventsForTree.firstWhere(
            (e) => (e['uuid'] ?? e['id'])?.toString() == selectedHarvestUuid,
            orElse: () => <String, dynamic>{});
        if (matched.isNotEmpty) {
          matchedEventLabel = (matched['event_name'] ?? matched['name'] ?? matched['title'] ?? matched['event'])?.toString();
          final startRaw = matched['start_date'] ?? matched['start'];
          if (startRaw != null && startRaw.toString().isNotEmpty) {
            try {
              final startDt = DateTime.parse(startRaw.toString());
              _matchedEventStartDate = DateTime(startDt.year, startDt.month, startDt.day);
            } catch (_) {
              _matchedEventStartDate = null;
            }
          } else {
            _matchedEventStartDate = null;
          }
        } else {
          matchedEventLabel = null;
          _matchedEventStartDate = null;
        }
      } else {
        matchedEventLabel = null;
        _matchedEventStartDate = null;
      }
    }
    _selectedGrade ??= gradeController.text.isNotEmpty
        ? gradeController.text
        : null;
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
              matchedEventLabel = (event['event_name'] ?? event['name'] ?? event['title'] ?? event['event'])?.toString();
              _matchedEventStartDate = start;
            });
            return;
          }
        } else {
          final endDt = DateTime.parse(endRaw.toString());
          final end = DateTime(endDt.year, endDt.month, endDt.day);
          if (!picked.isBefore(start) && !picked.isAfter(end)) {
            setState(() {
              selectedHarvestUuid = event['uuid'];
              matchedEventLabel = (event['event_name'] ?? event['name'] ?? event['title'] ?? event['event'])?.toString();
              _matchedEventStartDate = start;
            });
            return;
          }
        }
      } catch (_) {}
    }

    setState(() {
      selectedHarvestUuid = null;
      matchedEventLabel = null;
      _matchedEventStartDate = null;
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

    // Enforce harvested date not before matched harvest event start
    final pickedDateStr = harvestedAtController.text;
    if (pickedDateStr.isNotEmpty) {
      try {
        final pickedDate = DateTime.parse(pickedDateStr);
        final matchedEvent = events.firstWhere(
          (e) => (e['uuid'] ?? e['id'])?.toString() == selectedHarvestUuid,
          orElse: () => <String, dynamic>{},
        );
        final startRaw = matchedEvent['start_date'] ?? matchedEvent['start'];
        if (startRaw != null && startRaw.toString().isNotEmpty) {
          final start = DateTime.parse(startRaw.toString());
          final startDateOnly = DateTime(start.year, start.month, start.day);
          final pickedDateOnly =
              DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
          if (pickedDateOnly.isBefore(startDateOnly)) {
            await Flushbar(
              message: "Harvested date must be on/after the event start date",
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.orange,
            ).show(context);
            return;
          }
        }
      } catch (_) {}
    }

    setState(() => isLoading = true);

    try {
      final treeUuid = selectedTreeUuid!;
      final harvestEventUuid = selectedHarvestUuid!;  // UUID of the harvest event
      final weight = double.parse(weightController.text);
      final grade = gradeController.text;
      final harvestedAt = harvestedAtController.text;

      final online = await isOnline();
      final isEdit = widget.fruit != null;
      final fruitUuid = isEdit ? (widget.fruit!['uuid']?.toString() ?? '') : '';
      
      // Generate fruit tag in FR0000-XX format
      final nextFruitTag = await FruitDB().getNextFruitTag();
      
      late FruitModel fruitModel;
      
      // Determine the IDs to use
      String localFruitUuid;  // The fruit's own UUID
      String localHarvestUuid;  // The harvest event UUID
      
      if (isEdit && fruitUuid.isNotEmpty) {
        // Editing: use existing fruit UUID
        localFruitUuid = fruitUuid;
        localHarvestUuid = widget.fruit!['harvest_uuid']?.toString() ?? harvestEventUuid;
      } else if (online) {
        // Creating online: harvest_uuid is known, fruit uuid will come from server
        localFruitUuid = '';  // Will be set after server response
        localHarvestUuid = harvestEventUuid;
      } else {
        // Creating offline: generate temp fruit uuid, harvest_uuid is known
        localFruitUuid = 'gen_${DateTime.now().millisecondsSinceEpoch}';
        localHarvestUuid = harvestEventUuid;
      }
      
      fruitModel = FruitModel(
        fruit_tag: nextFruitTag,
        harvest_uuid: localHarvestUuid,  // The harvest event UUID
        uuid: localFruitUuid.isNotEmpty ? localFruitUuid : null,  // The fruit's UUID
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
          if (isEdit && fruitUuid.isNotEmpty) {
            await FruitApi.updateFruit(
              uuid: fruitUuid,
              tree_uuid: treeUuid,
              harvest_uuid: harvestEventUuid,
              weight: weight,
              grade: grade,
              harvested_at: harvestedAt,
              is_spoiled: isSpoiled,
            );
          } else {
            final response = await FruitApi.createFruit(
              tree_uuid: treeUuid,
              harvest_uuid: harvestEventUuid,
              weight: weight,
              grade: grade,
              harvested_at: harvestedAt,
              is_spoiled: isSpoiled,
            );
            
            // Extract real fruit UUID from server response
            try {
              final serverData = response['data'] is Map ? response['data'] : response;
              final serverFruitUuid = serverData['uuid'] ?? serverData['id'];
              if (serverFruitUuid != null && serverFruitUuid.toString().isNotEmpty) {
                print('✅ Server created fruit with UUID: $serverFruitUuid');
                // Create new fruitModel with server fruit UUID and synced flag
                fruitModel = FruitModel(
                  fruit_tag: fruitModel.fruit_tag,
                  harvest_uuid: localHarvestUuid,  // Keep the harvest event UUID
                  uuid: serverFruitUuid.toString(),  // Set the server fruit UUID
                  transaction_uuid: fruitModel.transaction_uuid,
                  harvested_at: fruitModel.harvested_at,
                  created_at: fruitModel.created_at,
                  is_spoiled: fruitModel.is_spoiled,
                  tree_uuid: fruitModel.tree_uuid,
                  weight: fruitModel.weight,
                  grade: fruitModel.grade,
                  synced: 1, // Mark as synced
                  pendingUpdate: 0,
                  pendingDelete: 0,
                );
              }
            } catch (e) {
              print('⚠️ Could not extract server UUID: $e');
            }
          }
          // Mark as synced after successful online save (if not already)
          if (fruitModel.synced != 1) {
            fruitModel = FruitModel(
              fruit_tag: fruitModel.fruit_tag,
              harvest_uuid: fruitModel.harvest_uuid,
              uuid: fruitModel.uuid,
              transaction_uuid: fruitModel.transaction_uuid,
              harvested_at: fruitModel.harvested_at,
              created_at: fruitModel.created_at,
              is_spoiled: fruitModel.is_spoiled,
              tree_uuid: fruitModel.tree_uuid,
              weight: fruitModel.weight,
              grade: fruitModel.grade,
              synced: 1, // Mark as synced
              pendingUpdate: 0,
              pendingDelete: 0,
            );
          }
          
          // Save the fruit to local database
          try {
            if (isEdit && fruitUuid.isNotEmpty) {
              await FruitDB().updateFruit(fruitModel);
            } else {
              await FruitDB().insertFruit(fruitModel);
            }
          } catch (dbErr) {
            print('⚠️ Failed to save fruit to local DB after online success: $dbErr');
          }
        } catch (e) {
          print('⚠️ FruitApi.${isEdit ? "updateFruit" : "createFruit"} failed, saving locally: $e');
          try {
            if (isEdit && fruitUuid.isNotEmpty) {
              await FruitDB().updateFruit(fruitModel);
            } else {
              await FruitDB().insertFruit(fruitModel);
            }
            savedLocally = true;
          } catch (insertErr) {
            print('⚠️ Failed to save fruit locally after API failure: $insertErr');
            rethrow;
          }
        }
      } else {
        if (isEdit && fruitUuid.isNotEmpty) {
          await FruitDB().updateFruit(fruitModel);
        } else {
          await FruitDB().insertFruit(fruitModel);
        }
        try {
          final unsynced = await FruitDB().getUnsyncedFruits();
          print('🍏 Saved fruit locally (fruit_uuid=${fruitModel.uuid}, harvest_uuid=${fruitModel.harvest_uuid}). Unsynced count=${unsynced.length}');
        } catch (e) {
          print('⚠️ Could not read unsynced fruits after insert: $e');
        }
        savedLocally = true;
      }

      if (mounted) {
        try {
          if (online && !savedLocally) {
            await Flushbar(
              message: widget.fruit == null ? 'Fruit created successfully' : 'Fruit updated successfully',
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

            // Print pending sync counts
            await AppInitializer.printPendingSyncCounts();
          }
        } catch (_) {}
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
      if (mounted) {
        setState(() => isLoading = false);
      }
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
        actions: widget.fruit != null
            ? [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () async {
                    final shouldDelete = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Fruit'),
                        content: const Text(
                          'Are you sure you want to delete this fruit?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (shouldDelete == true) {
                      try {
                        final fruitUuid = widget.fruit!['uuid'];
                        if (fruitUuid != null) {
                          await FruitApi.deleteFruit(fruitUuid.toString());
                          if (mounted) {
                            await Flushbar(
                              message: 'Fruit deleted successfully',
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                              ),
                              backgroundColor: Colors.green.shade700,
                              duration: const Duration(seconds: 2),
                              borderRadius: BorderRadius.circular(12),
                              margin: const EdgeInsets.all(12),
                              flushbarPosition: FlushbarPosition.TOP,
                            ).show(context);
                            Navigator.pop(context, true);
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          await Flushbar(
                            message: 'Error deleting fruit: $e',
                            icon: const Icon(Icons.error, color: Colors.white),
                            backgroundColor: Colors.red.shade700,
                            duration: const Duration(seconds: 3),
                            borderRadius: BorderRadius.circular(8),
                            margin: const EdgeInsets.all(12),
                          ).show(context);
                        }
                      }
                    }
                  },
                ),
              ]
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Show fruit tag when editing
              if (widget.fruit != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      initialValue: widget.fruit!['fruit_tag']?.toString() ?? 'Unknown',
                      readOnly: true,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: 'Fruit',
                        filled: true,
                        fillColor: AppColors.gray100,
                      ),
                      style: TextStyle(
                        color: AppColors.gray700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              FormField<String>(
                validator: (value) =>
                    selectedTreeUuid == null || selectedTreeUuid!.isEmpty
                        ? 'Please select a tree'
                        : null,
                builder: (field) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final menuWidth = constraints.maxWidth;
                          return SizedBox(
                            width: double.infinity,
                            child: DropdownMenu<String>(
                              width: menuWidth,
                              controller: _treeController,
                              requestFocusOnTap: true,
                              initialSelection: selectedTreeUuid,
                              label: const Text('Tree'),
                              menuHeight: 300,
                              dropdownMenuEntries: trees
                                  .map<DropdownMenuEntry<String>>(
                                    (tree) => DropdownMenuEntry(
                                      value: tree['uuid']?.toString() ?? '',
                                      label:
                                          tree['tree_tag']?.toString() ?? 'Unknown',
                                    ),
                                  )
                                  .toList(),
                              onSelected: (value) async {
                                if (value == null || value.isEmpty) return;
                                setState(() {
                                  selectedTreeUuid = value;
                                  selectedHarvestUuid = null;
                                  events = [];
                                  matchedEventLabel = null;
                                  _treeController.text = trees
                                          .firstWhere(
                                            (t) => t['uuid']?.toString() == value,
                                            orElse: () => <String, String>{'tree_tag': ''},
                                          )['tree_tag']
                                          ?.toString() ??
                                      '';
                                });
                                await _loadEventsForTree(value);
                                field.didChange(value);
                              },
                            ),
                          );
                        },
                      ),
                      if (field.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 12),
                          child: Text(
                            field.errorText!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  );
                },
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
                  final firstDate = _matchedEventStartDate ?? DateTime(2000);
                  DateTime lastDate = DateTime.now();
                  if (firstDate.isAfter(lastDate)) {
                    lastDate = firstDate;
                  }
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: lastDate,
                    firstDate: firstDate,
                    lastDate: lastDate,
                  );
                  if (pickedDate != null) {
                    harvestedAtController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                    _updateHarvestEventForDate(pickedDate);
                  }
                },
                validator: (value) => value == null || value.isEmpty ? 'Pick a date' : null,
              ),
              const SizedBox(height: 12),

              // Enhanced Events Matched Display
              if (events.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        matchedEventLabel != null
                            ? AppColors.hunterGreen.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        matchedEventLabel != null
                            ? AppColors.mossGreen.withOpacity(0.05)
                            : Colors.orange.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: matchedEventLabel != null
                          ? AppColors.hunterGreen.withOpacity(0.3)
                          : Colors.orange.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: matchedEventLabel != null
                              ? AppColors.hunterGreen.withOpacity(0.15)
                              : Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          matchedEventLabel != null ? Icons.event_available : Icons.event_busy,
                          color: matchedEventLabel != null ? AppColors.hunterGreen : Colors.orange.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Harvest Event',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: matchedEventLabel != null
                                    ? AppColors.hunterGreen
                                    : Colors.orange.shade700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              matchedEventLabel ?? 'No event matched for this date',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: matchedEventLabel != null ? AppColors.gray800 : AppColors.gray600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              FormField<String>(
                validator: (value) =>
                    _selectedGrade == null || _selectedGrade!.isEmpty
                        ? 'Select grade'
                        : null,
                builder: (field) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final menuWidth = constraints.maxWidth;
                          return SizedBox(
                            width: double.infinity,
                            child: DropdownMenu<String>(
                              width: menuWidth,
                              controller: gradeController,
                              requestFocusOnTap: true,
                              initialSelection: _selectedGrade,
                              label: const Text('Grade'),
                              dropdownMenuEntries: _gradeOptions
                                  .map<DropdownMenuEntry<String>>(
                                    (g) => DropdownMenuEntry(
                                      value: g,
                                      label: g,
                                    ),
                                  )
                                  .toList(),
                              onSelected: (value) {
                                setState(() {
                                  _selectedGrade = value;
                                  gradeController.text = value ?? '';
                                  field.didChange(value);
                                });
                              },
                            ),
                          );
                        },
                      ),
                      if (field.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 12),
                          child: Text(
                            field.errorText!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: weightController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Weight (kg)',
                  hintText: 'Enter weight in kg (e.g., 2.5)',
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter weight';
                  if (double.tryParse(value) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Enhanced Is Spoiled Design
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSpoiled ? Colors.red.withOpacity(0.3) : AppColors.gray300,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        isSpoiled = !isSpoiled;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSpoiled
                                  ? Colors.red.withOpacity(0.1)
                                  : AppColors.hunterGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isSpoiled ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                              color: isSpoiled ? Colors.red.shade700 : AppColors.hunterGreen,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Fruit Condition',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.gray600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isSpoiled ? 'Spoiled' : 'Fresh',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isSpoiled ? Colors.red.shade700 : AppColors.hunterGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Transform.scale(
                            scale: 0.9,
                            child: Switch(
                              value: isSpoiled,
                              onChanged: (value) {
                                setState(() {
                                  isSpoiled = value;
                                });
                              },
                              activeColor: Colors.red.shade700,
                              activeTrackColor: Colors.red.shade200,
                              inactiveThumbColor: AppColors.hunterGreen,
                              inactiveTrackColor: AppColors.hunterGreen.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: isLoading ? null : _saveFruit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pakistanGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}