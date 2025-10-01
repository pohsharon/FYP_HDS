import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/tree_api.dart';
import 'package:fyp_hbs/services/fruit_api.dart';

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
    final fetchedTrees = await TreeApi.fetchTrees();

    // Extract the 'data' list from the fetchedTrees Map
    final treeList = List<Map<String, dynamic>>.from(fetchedTrees['data']);

    setState(() {
      trees = treeList; // assign only the list part to your trees variable
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error fetching trees: $e")),
    );
  }
}


  Future<void> _fetchEvents() async {
    try {
      final fetchedEvents = await TreeApi.fetchEvents();
      setState(() {
        events = fetchedEvents;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error fetching events: $e")));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a tree")));
      return;
    }
    if (selectedHarvestUuid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No valid harvest event for this date")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await FruitApi.createFruit(
        tree_uuid: selectedTreeUuid!,
        harvest_uuid: selectedHarvestUuid!,
        weight: double.parse(weightController.text),
        grade: gradeController.text,
        harvested_at: harvestedAtController.text,
        is_spoiled: isSpoiled,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fruit created successfully")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving fruit: $e")));
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
