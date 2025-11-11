import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/tree_api.dart';
import 'package:fyp_hbs/services/api/fruit_api.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fyp_hbs/services/local_db.dart'; 
import 'package:fyp_hbs/models/fruit_model.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchTrees();
    _fetchEvents();
  }

  Future<void> _fetchTrees() async {
  try {
    final response = await TreeApi.fetchAllTrees();
    List<Map<String, dynamic>> treeList = [];
    try {
      // Try to extract nested list at response['data']['data'] (API shape)
      final nested = (response as dynamic)['data']['data'];
      if (nested is List) {
        treeList = nested.map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (response is List) {
        final respList = response as List;
        treeList = respList.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {
      // ignore and fall through to potential local DB fallback
    }


    if (treeList.isEmpty) {
      // Fallback: read from local DB (useful when offline)
      try {
        final local = await LocalDB.instance.fetchAllTrees();
        treeList = local
            .map((t) => {
                  'uuid': t.uuid,
                  'tree_tag': t.treeTag ?? 'Unknown',
                })
            .toList();
      } catch (e) {
        print('⚠️ _fetchTrees fallback failed: $e');
      }
    }

    setState(() {
      trees = treeList;
    });
  } catch (e) {
   print(e);
  }
}

  Future<void> _fetchEvents() async {
    try {
      final fetchedEvents = await TreeApi.fetchEvents();
      setState(() {
        events = fetchedEvents;
      });
    } catch (e) {
      print(e);
  }

  void _updateHarvestEventForDate(DateTime date) {
    for (var event in events) {
      final start = DateTime.parse(event['start_date']);
      final endDateStr = event['end_date'];

      // Handle active event (no end date yet)
      if (endDateStr == null ||
          endDateStr.toString().isEmpty ||
          endDateStr == "null") {
        if (date.isAtSameMomentAs(start) || date.isAfter(start)) {
          setState(() {
            selectedHarvestUuid = event['uuid'];
          });
          return;
        }
      } else {
        final end = DateTime.parse(endDateStr);

        if ((date.isAtSameMomentAs(start) || date.isAfter(start)) &&
            (date.isAtSameMomentAs(end) || date.isBefore(end))) {
          setState(() {
            selectedHarvestUuid = event['uuid'];
          });
          return;
        }
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

    if (await isOnline()) {
      await FruitApi.createFruit(
        tree_uuid: treeUuid,
        harvest_uuid: harvestUuid,
        weight: weight,
        grade: grade,
        harvested_at: harvestedAt,
        is_spoiled: isSpoiled,
      );

        // Don't show a Flushbar here because popping the route immediately after
        // can cause Navigator push/pop race conditions. The caller (list page)
        // should show confirmation when it receives the `true` result.
    } else {
      // Save locally using the FruitModel
      final fruitModel = FruitModel(
    fruit_tag: (grade.isNotEmpty)
      ? 'Grade $grade'
      : (harvestedAt.isNotEmpty)
        ? harvestedAt
        : (harvestUuid.length > 8 ? harvestUuid.substring(0, 8) : harvestUuid),
        harvest_uuid: harvestUuid,
        transaction_uuid: null,
        harvested_at: harvestedAt,
        is_spoiled: isSpoiled,
        tree_uuid: treeUuid,
        weight: weight,
        grade: grade,
        synced: 0,
        pendingUpdate: 0,
        pendingDelete: 0,
      );

      await LocalDB.instance.insertFruit(fruitModel);

        // Saved offline; don't show Flushbar here to avoid navigator locking.
        // The caller can show a notification after this page pops.
    }

    if (mounted) Navigator.pop(context, true);
  } catch (e) {
    Flushbar(
      message: "Error saving fruit: $e",
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.red,
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
                onChanged: (value) {
                  setState(() {
                    selectedTreeUuid = value;
                  });
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
