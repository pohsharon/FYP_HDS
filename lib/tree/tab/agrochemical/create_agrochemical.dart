import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/agrochemical_api.dart';
import 'package:fyp_hbs/utils/connectivity_helper.dart';
import 'package:fyp_hbs/services/local database/agro_db.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:fyp_hbs/models/agrochemical_model.dart';

class CreateAgrochemicalPage extends StatefulWidget {
  final Map<String, dynamic>? agrochemicalRecord;
  final String treeUuid;
  final String treeTag;

  const CreateAgrochemicalPage({
    super.key,
    this.agrochemicalRecord,
    required this.treeUuid,
    required this.treeTag,
  });

  @override
  _CreateAgrochemicalPageState createState() => _CreateAgrochemicalPageState();
}

class _CreateAgrochemicalPageState extends State<CreateAgrochemicalPage> {
  final _formKey = GlobalKey<FormState>();

  String? selectedAgrochemicalUuid;
  DateTime? appliedAt;
  final descriptionController = TextEditingController();
  final agrochemicalController = TextEditingController();

  bool isLoading = false;
  List<Map<String, dynamic>> _agrochemicalOptions = [];
  bool _isDropdownLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAgrochemicalOptions();
    // Pre-fill form when editing
    if (widget.agrochemicalRecord != null) {
      final record = widget.agrochemicalRecord!;
      selectedAgrochemicalUuid = record['agrochemical_uuid'];
      appliedAt = DateTime.tryParse(record['applied_at'] ?? '');
      descriptionController.text = record['description'] ?? '';
      agrochemicalController.text = record['agrochemical_name'] ?? '';
    }
  }

  @override
  void dispose() {
    descriptionController.dispose();
    agrochemicalController.dispose();
    super.dispose();
  }

  Future<void> _fetchAgrochemicalOptions() async {
    setState(() => _isDropdownLoading = true);
    try {
      final online = await ConnectivityHelper.hasInternetConnection();
      if (online) {
        final options = await AgrochemicalApi.getAvailableAgrochemicals();
        // cache master list locally for offline fallback
        try {
          await AgroDB().saveAgrochemicalList(options);
        } catch (e) {
          print('⚠️ Failed to save agrochemical master list locally: $e');
        }
        setState(() {
          _agrochemicalOptions = options;
          _isDropdownLoading = false;
        });
        return;
      }
    } catch (e) {
      print('⚠️ _fetchAgrochemicalOptions: remote fetch failed: $e');
    }

    // Fallback to local cached agrochemical master list
    try {
      final local = await AgroDB().getAllAgrochemicals();
      final mapped = local.map<Map<String, dynamic>>((row) {
        return {
          'uuid': (row['id'] ?? '').toString(),
          'name': row['agrochemical_name'] ?? 'Unknown',
        };
      }).toList();
      setState(() {
        _agrochemicalOptions = mapped;
        _isDropdownLoading = false;
      });
      } catch (e) {
      setState(() => _isDropdownLoading = false);
      await Flushbar(
        message: 'Error loading agrochemicals (offline): $e',
        icon: const Icon(Icons.error, color: Colors.white),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
        borderRadius: BorderRadius.circular(8),
        margin: const EdgeInsets.all(12),
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    }
  }

  Future<void> _saveLocally(String formattedDate) async {
    final selectedName = _agrochemicalOptions.firstWhere(
      (e) => (e['uuid'] ?? e['id'] ?? '') == selectedAgrochemicalUuid,
      orElse: () => {'name': 'Unknown'},
    )['name']?.toString();

    final model = AgrochemicalModel(
      tree_uuid: widget.treeUuid,
      agrochemicalId: selectedAgrochemicalUuid,
      agrochemicalName: selectedName,
      applied_at: formattedDate,
      description: descriptionController.text,
      synced: 0,
      pendingUpdate: widget.agrochemicalRecord != null ? 1 : 0,
    );

    try {
      await AgroDB().insertAgrochemical(model);
      print('✅ Saved agrochemical locally for tree=${widget.treeUuid}');
    } catch (e) {
      print('⚠️ Failed to save agrochemical locally: $e');
      rethrow;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: appliedAt ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => appliedAt = picked);
    }
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate() ||
        selectedAgrochemicalUuid == null ||
        appliedAt == null) {
      await Flushbar(
        message: 'Please complete all fields',
        icon: const Icon(Icons.error, color: Colors.white),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 2),
        borderRadius: BorderRadius.circular(8),
        margin: const EdgeInsets.all(12),
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
      return;
    }

    try {
      setState(() => isLoading = true);

      final formattedDate = DateFormat('yyyy-MM-dd').format(appliedAt!);

      final online = await ConnectivityHelper.hasInternetConnection();

      if (online) {
        // Attempt to create/update remotely. If remote fails, fall back to local save.
        try {
          if (widget.agrochemicalRecord == null) {
            // CREATE remotely
            await AgrochemicalApi.createAgrochemicalRecord(
              tree_uuid: widget.treeUuid,
              agrochemical_uuid: selectedAgrochemicalUuid!,
              applied_at: formattedDate,
              description: descriptionController.text,
            );
            await Flushbar(
              message: 'Agrochemical record created successfully',
              icon: const Icon(Icons.check_circle, color: Colors.white),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 2),
              borderRadius: BorderRadius.circular(12),
              margin: const EdgeInsets.all(12),
              flushbarPosition: FlushbarPosition.TOP,
            ).show(context);
          } else {
            // UPDATE remotely
            await AgrochemicalApi.updateAgrochemicalRecord(
              tree_uuid: widget.treeUuid,
              record_uuid: widget.agrochemicalRecord!['uuid'],
              agrochemical_uuid: selectedAgrochemicalUuid!,
              applied_at: formattedDate,
              description: descriptionController.text,
            );
            await Flushbar(
              message: 'Agrochemical record updated successfully',
              icon: const Icon(Icons.check_circle, color: Colors.white),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 2),
              borderRadius: BorderRadius.circular(12),
              margin: const EdgeInsets.all(12),
              flushbarPosition: FlushbarPosition.TOP,
            ).show(context);
          }
        } catch (e) {
          print('⚠️ Remote agrochemical save failed, saving locally instead: $e');
          // fall through to local save below
          await _saveLocally(formattedDate);
          await Flushbar(
            message: 'Saved locally — will sync when online',
            icon: const Icon(Icons.cloud_off, color: Colors.white),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 2),
            borderRadius: BorderRadius.circular(12),
            margin: const EdgeInsets.all(12),
            flushbarPosition: FlushbarPosition.TOP,
          ).show(context);
        }
      } else {
        // Offline: save locally and mark as unsynced
        await _saveLocally(formattedDate);
        await Flushbar(
          message: 'Saved locally — will sync when online',
          icon: const Icon(Icons.cloud_off, color: Colors.white),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 2),
          borderRadius: BorderRadius.circular(12),
          margin: const EdgeInsets.all(12),
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      }

      Navigator.pop(context, true);
    } catch (e) {
      await Flushbar(
        message: 'Error: $e',
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
    final isEdit = widget.agrochemicalRecord != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Agro Record' : 'Add Agrochemical Record',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.pakistanGreen,
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: isLoading
                  ? null
                  : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Record'),
                          content: const Text('Are you sure you want to delete this agrochemical record?'),
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
                          setState(() => isLoading = true);
                          await AgrochemicalApi.deleteAgrochemicalRecord(
                            widget.agrochemicalRecord!['uuid'],
                          );
                          if (!mounted) return;
                          Navigator.pop(context, true);
                        } catch (e) {
                          await Flushbar(
                            message: 'Error deleting record: $e',
                            icon: const Icon(Icons.error, color: Colors.white),
                            backgroundColor: Colors.red.shade700,
                            duration: const Duration(seconds: 3),
                            borderRadius: BorderRadius.circular(8),
                            margin: const EdgeInsets.all(12),
                            flushbarPosition: FlushbarPosition.TOP,
                          ).show(context);
                        } finally {
                          if (mounted) setState(() => isLoading = false);
                        }
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
              const SizedBox(height: 16),

              // Pre-filled tree tag for context
              TextFormField(
                initialValue: widget.treeTag,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Tree Tag',
                  filled: true,
                  fillColor: AppColors.gray200,
                ),
                readOnly: true,
              ),

              const SizedBox(height: 16),

              // Replace with Material 3 DropdownMenu to match Create Tree styling
              LayoutBuilder(builder: (context, constraints) {
                final menuWidth = constraints.maxWidth;
                if (_isDropdownLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return SizedBox(
                  width: double.infinity,
                  child: DropdownMenu<String>(
                    width: max(menuWidth, 360),
                    menuHeight: 320,
                    controller: agrochemicalController,
                    requestFocusOnTap: true,
                    initialSelection: selectedAgrochemicalUuid,
                    label: const Text('Agrochemical'),
                    dropdownMenuEntries: _agrochemicalOptions
                        .map<DropdownMenuEntry<String>>((item) => DropdownMenuEntry(
                              value: (item['uuid'] ?? item['id'] ?? '').toString(),
                              label: item['name']?.toString() ?? 'Unknown',
                            ))
                        .toList(),
                    onSelected: (String? v) {
                      setState(() => selectedAgrochemicalUuid = v);
                    },
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Date picker
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Applied At',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  child: Text(
                    appliedAt != null
                        ? DateFormat('yyyy-MM-dd').format(appliedAt!)
                        : 'Select date',
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Description',
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: isLoading ? null : _saveRecord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pakistanGreen,
                ),
                child:
                    isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                          isEdit ? 'Update' : 'Save',
                          style: const TextStyle(color: Colors.white),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
