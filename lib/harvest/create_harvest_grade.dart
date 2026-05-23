import 'package:flutter/material.dart';
import 'dart:math';
import 'package:another_flushbar/flushbar.dart';
import 'package:fyp_hbs/harvest/widgets/harvest_info_modal.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/harvest_api.dart';
import 'package:fyp_hbs/services/api/tree_api.dart';

class CreateHarvestGradePage extends StatefulWidget {
  const CreateHarvestGradePage({super.key});

  @override
  State<CreateHarvestGradePage> createState() => _CreateHarvestGradePageState();
}

class _CreateHarvestGradePageState extends State<CreateHarvestGradePage> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _gradeController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _speciesController = TextEditingController();

  // species dropdown
  List<Map<String, dynamic>> speciesList = [];
  String? selectedSpeciesId;

  // grade dropdown
  String? selectedGrade;

  String? _activeHarvestUuid;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _gradeController.text = 'All Grades'; // Set default
    selectedGrade = null; // Default to "All Grades"
    _initActiveHarvest();
    _fetchSpecies();
  }

  Future<void> _initActiveHarvest() async {
    try {
      final active = await HarvestApi.fetchActiveHarvest();
      final id =
          (active['uuid'] ?? active['harvest_uuid'] ?? active['id'])
              ?.toString();
      if (id != null && id.isNotEmpty) setState(() => _activeHarvestUuid = id);
    } catch (_) {}
  }

  @override
  void dispose() {
    _dateController.dispose();
    _gradeController.dispose();
    _weightController.dispose();
    _speciesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_activeHarvestUuid == null || _activeHarvestUuid!.isEmpty) {
      await Flushbar(
        message: 'No active harvest found. Cannot create record.',
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ).show(context);
      return;
    }

    final date = _dateController.text;
    if (date.isEmpty) {
      await Flushbar(
        message: 'Please select a date',
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 2),
      ).show(context);
      return;
    }

    final speciesId =
        (selectedSpeciesId != null && selectedSpeciesId!.isNotEmpty)
            ? int.tryParse(selectedSpeciesId!)
            : null;
    final grade =
        (selectedGrade != null && selectedGrade!.isNotEmpty)
            ? selectedGrade
            : null;
    final weight = double.tryParse(_weightController.text);

    setState(() => _loading = true);
    try {
      // Check for duplicate: same date, species_id, and grade
      final gradesResponse = await HarvestApi.fetchHarvestGradesByDate(
        date: date,
      );
      final grades = gradesResponse['data'] as List? ?? [];

      Map<String, dynamic>? existingRecord;
      for (final item in grades) {
        if (item is Map) {
          final itemSpeciesId = item['species_id'];
          final itemGrade = item['grade'];

          // Match if both species_id and grade are the same
          if (itemSpeciesId == speciesId && itemGrade == grade) {
            existingRecord = Map<String, dynamic>.from(item);
            break;
          }
        }
      }

      // If duplicate found, ask user to replace or add new
      if (existingRecord != null && mounted) {
        setState(() => _loading = false);

        // Calculate species total for this day
        double speciesTotal = 0;
        final targetSpeciesId = speciesId?.toString();
        for (final item in grades) {
          if (item is Map) {
            final itemSpeciesId = item['species_id']?.toString();
            final matchesSpecies = targetSpeciesId == null || itemSpeciesId == targetSpeciesId;
            if (!matchesSpecies) continue;

            speciesTotal += _parseWeightValue(item['weight']);
          }
        }

        final inputWeightStr =
          weight != null ? weight.toStringAsFixed(2) : 'N/A';
        final savedWeight = existingRecord['weight'];
        final savedWeightDouble =
          savedWeight is num
            ? savedWeight.toDouble()
            : (savedWeight is String ? double.tryParse(savedWeight) : null);
        final speciesTotalStr = speciesTotal.toStringAsFixed(2);
        final existingGrade = existingRecord['grade'] ?? 'N/A';

        final action = await showDialog<String>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Container(
                padding: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.green.shade600, width: 2),
                  ),
                ),
                child: const Text(
                  'Record Already Exists',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Duplicate detected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Same date, species, and grade',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Grade', existingGrade),
                  const SizedBox(height: 8),
                  _buildInfoRow('Record Weight', '$inputWeightStr kg'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Weight saved: $speciesTotalStr kg',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'What would you like to do?',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop('add'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Add New',
                        style: TextStyle(color: Colors.blue),
                      ),
                      const SizedBox(height: 2),
                    
                    ],
                  ),
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed:
                          () => Navigator.of(dialogContext).pop('cancel'),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed:
                          () => Navigator.of(dialogContext).pop('replace'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Replace',
                            style: TextStyle(color: Colors.white),
                          ),
                         
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );

        if (action == null || action == 'cancel') return;

        setState(() => _loading = true);

        try {
          if (action == 'replace') {
            // Update existing record
            await HarvestApi.updateHarvestGrade(
              id: existingRecord['id'],
              harvestUuid: _activeHarvestUuid!,
              date: date,
              speciesId: speciesId,
              grade: grade,
              weight: weight,
            );

            await Flushbar(
              message: 'Harvest grade updated',
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 2),
            ).show(context);
          } else {
            // Add to existing: sum existing weight + newly entered weight, then update
            final existingW = savedWeightDouble ?? 0.0;
            final incomingW = weight ?? 0.0;
            final newTotal = existingW + incomingW;

            await HarvestApi.updateHarvestGrade(
              id: existingRecord['id'],
              harvestUuid: _activeHarvestUuid!,
              date: date,
              speciesId: speciesId,
              grade: grade,
              weight: newTotal,
            );

            await Flushbar(
              message: 'Harvest grade updated (summed)',
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 2),
            ).show(context);
          }

          if (mounted) Navigator.of(context).pop();
        } catch (e) {
          await Flushbar(
            message: 'Operation failed: $e',
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ).show(context);
        } finally {
          if (mounted) setState(() => _loading = false);
        }
      } else {
        // No duplicate, create new record normally
        final resp = await HarvestApi.storeHarvestGrade(
          harvestUuid: _activeHarvestUuid!,
          date: date,
          speciesId: speciesId,
          grade: grade,
          weight: weight,
        );

        await Flushbar(
          message: 'Harvest grade created',
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
        ).show(context);
        if (mounted) Navigator.of(context).pop(resp);
      }
    } catch (e) {
      await Flushbar(
        message: 'Failed to check for duplicates: $e',
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ).show(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _parseWeightValue(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Future<void> _fetchSpecies() async {
    try {
      final fetchedSpecies = await TreeApi.fetchSpecies();
      if (mounted) {
        setState(() {
          speciesList = fetchedSpecies;
          selectedSpeciesId = null; // Default to "All Species"
          _speciesController.text = 'All Species';
        });
      }
    } catch (e) {
      if (mounted) {
        Flushbar(
          message: 'Error fetching species: $e',
          icon: const Icon(Icons.error, color: Colors.white),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          borderRadius: BorderRadius.circular(8),
          margin: const EdgeInsets.all(12),
        ).show(context);
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.green.shade700,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.pakistanGreen,
        title: const Text(
          'Create Harvest Grade',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Harvest info',
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => showHarvestInfoModal(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _dateController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Date',
                prefixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null)
                  _dateController.text =
                      picked.toIso8601String().split('T').first;
              },
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final menuWidth = constraints.maxWidth;
                return SizedBox(
                  width: double.infinity,
                  child: DropdownMenu<String?>(
                    width: max(menuWidth, 240),
                    controller: _speciesController,
                    requestFocusOnTap: true,
                    initialSelection: selectedSpeciesId,
                    label: const Text('Species'),
                    menuHeight: 300,
                    dropdownMenuEntries:
                        <DropdownMenuEntry<String?>>[
                          const DropdownMenuEntry<String?>(
                            value: null,
                            label: 'All Species',
                          ),
                        ] +
                        speciesList
                            .map<DropdownMenuEntry<String?>>(
                              (species) => DropdownMenuEntry(
                                value: species['id'].toString(),
                                label: species['name']?.toString() ?? '',
                              ),
                            )
                            .toList(),
                    onSelected: (String? v) {
                      setState(() {
                        selectedSpeciesId = v;
                        if (v == null) {
                          _speciesController.text = 'All Species';
                        } else {
                          try {
                            final found = speciesList.firstWhere(
                              (s) => s['id'].toString() == v,
                            );
                            _speciesController.text =
                                found['name']?.toString() ?? '';
                          } catch (_) {
                            _speciesController.text = '';
                          }
                        }
                      });
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final menuWidth = constraints.maxWidth;
                return SizedBox(
                  width: double.infinity,
                  child: DropdownMenu<String?>(
                    width: max(menuWidth, 240),
                    controller: _gradeController,
                    requestFocusOnTap: true,
                    initialSelection: selectedGrade,
                    label: const Text('Grade'),
                    menuHeight: 250,
                    dropdownMenuEntries: <DropdownMenuEntry<String?>>[
                      const DropdownMenuEntry<String?>(
                        value: null,
                        label: 'All Grades',
                      ),
                      const DropdownMenuEntry<String?>(value: 'A', label: 'A'),
                      const DropdownMenuEntry<String?>(
                        value: 'AB',
                        label: 'AB',
                      ),
                      const DropdownMenuEntry<String?>(value: 'B', label: 'B'),
                      const DropdownMenuEntry<String?>(value: 'C', label: 'C'),
                      const DropdownMenuEntry<String?>(
                        value: 'CC',
                        label: 'CC',
                      ),
                      const DropdownMenuEntry<String?>(value: 'Z', label: 'Z'),
                    ],
                    onSelected: (String? v) {
                      setState(() {
                        selectedGrade = v;
                        _gradeController.text = v ?? 'All Grades';
                      });
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.hunterGreen,
                ),
                onPressed: _loading ? null : _save,
                child:
                    _loading
                        ? const CircularProgressIndicator()
                        : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
