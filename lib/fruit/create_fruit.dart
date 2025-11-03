import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/tree_api.dart';
import 'package:fyp_hbs/services/api/fruit_api.dart';
import 'package:another_flushbar/flushbar.dart';

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

    if (widget.fruit != null) {
      final f = widget.fruit!;
      weightController.text = f['weight']?.toString() ?? '';
      gradeController.text = f['grade']?.toString() ?? '';
      harvestedAtController.text = f['harvested_at']?.toString() ?? '';
      isSpoiled = (f['is_spoiled'] as bool?) ?? false;
      selectedTreeUuid = f['tree_uuid'];
      selectedHarvestUuid = f['harvest_uuid'];
    }
  }

  Future<void> _fetchTrees() async {
    try {
      final response = await TreeApi.fetchAllTrees();
      final treeList =
          (response['data']['data'] as List<dynamic>)
              .map((tree) => tree as Map<String, dynamic>)
              .toList();

      setState(() {
        trees = treeList;

        // ✅ Reset selectedTreeUuid if it doesn't exist in dropdown items
        if (selectedTreeUuid != null &&
            !trees.any((tree) => tree['uuid'] == selectedTreeUuid)) {
          selectedTreeUuid = null;
        }
      });
    } catch (e) {
      await Flushbar(
        message: 'Error fetching trees: $e',
        icon: const Icon(Icons.error, color: Colors.white),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ).show(context);
    }
  }

  Future<void> _fetchEvents() async {
    try {
      final fetchedEvents = await TreeApi.fetchEvents();
      setState(() {
        events = fetchedEvents;
      });
    } catch (e) {
      await Flushbar(
        message: 'Error fetching events: $e',
        icon: const Icon(Icons.error, color: Colors.white),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
        borderRadius: BorderRadius.circular(8),
        margin: const EdgeInsets.all(12),
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    }
  }

  void _updateHarvestEventForDate(DateTime date) {
    print(events);
    for (var event in events) {
      final start = DateTime.parse(event['start_date']);
      final endDateStr = event['end_date'];

      print("Picked date: $date");
      for (var event in events) {
        print(
          "Event: ${event['uuid']} start=${event['start_date']} end=${event['end_date']}",
        );
      }

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

  Future<void> _saveFruit() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedTreeUuid == null) {
      await Flushbar(
        message: 'Please select a tree',
        icon: const Icon(Icons.info_outline, color: Colors.white),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 2),
        borderRadius: BorderRadius.circular(8),
        margin: const EdgeInsets.all(12),
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
      return;
    }
    if (selectedHarvestUuid == null) {
      await Flushbar(
        message: 'No valid harvest event for this date',
        icon: const Icon(Icons.info_outline, color: Colors.white),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 2),
        borderRadius: BorderRadius.circular(8),
        margin: const EdgeInsets.all(12),
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
      return;
    }

    try {
      setState(() => isLoading = true);

      if (widget.fruit == null) {
        await FruitApi.createFruit(
          tree_uuid: selectedTreeUuid!,
          harvest_uuid: selectedHarvestUuid!,
          weight: double.parse(weightController.text),
          grade: gradeController.text,
          harvested_at: harvestedAtController.text,
          is_spoiled: isSpoiled,
        );
      } else {
        await FruitApi.updateFruit(
          uuid: widget.fruit!['uuid'],
          tree_uuid: selectedTreeUuid!,
          harvest_uuid: selectedHarvestUuid!,
          weight: double.parse(weightController.text),
          grade: gradeController.text,
          harvested_at: harvestedAtController.text,
          is_spoiled: isSpoiled,
        );
      }

      if (mounted) {
        await Flushbar(
          message:
              widget.fruit == null
                  ? 'Fruit created successfully'
                  : 'Fruit updated successfully',
          icon: const Icon(Icons.check_circle, color: Colors.white),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
          borderRadius: BorderRadius.circular(12),
          margin: const EdgeInsets.all(12),
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);

        Future.microtask(() {
          if (!mounted) return;
          Navigator.pop(context, true);
        });
      }
    } catch (e) {
      await Flushbar(
        message: 'Error saving fruit: $e',
        icon: const Icon(Icons.error, color: Colors.white),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
        borderRadius: BorderRadius.circular(8),
        margin: const EdgeInsets.all(12),
        flushbarPosition: FlushbarPosition.TOP,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () async {
              if (widget.fruit != null) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Delete Fruit'),
                        content: const Text(
                          'Are you sure you want to delete this fruit?',
                        ),
                        backgroundColor: Colors.white,
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                );

                if (confirm == true) {
                  try {
                    await FruitApi.deleteFruit(
                      widget.fruit!['uuid'].toString(),
                    );

                    // show flushbar and wait for it to finish before navigating
                    await Flushbar(
                      message: 'Fruit deleted successfully',
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      backgroundColor: Colors.green.shade700,
                      duration: const Duration(seconds: 2),
                      borderRadius: BorderRadius.circular(12),
                      margin: const EdgeInsets.all(12),
                      flushbarPosition: FlushbarPosition.TOP,
                    ).show(context);

                    if (!mounted) return;
                    // Close this page and return `true` to indicate deletion
                    Navigator.pop(context, true);
                  } catch (e) {
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
              } else {
                await Flushbar(
                  message: 'No fruit to delete',
                  icon: const Icon(Icons.info, color: Colors.white),
                  backgroundColor: Colors.grey.shade700,
                  duration: const Duration(seconds: 2),
                  borderRadius: BorderRadius.circular(8),
                  margin: const EdgeInsets.all(12),
                ).show(context);
              }
            },
          ),
        ],
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
