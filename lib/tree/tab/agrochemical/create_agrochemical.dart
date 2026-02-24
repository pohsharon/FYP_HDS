import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/agrochemical_api.dart';
import 'package:fyp_hbs/services/api/tree_api.dart';
import 'package:fyp_hbs/utils/connectivity_helper.dart';
import 'package:fyp_hbs/services/local database/agro_db.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:fyp_hbs/models/agrochemical_model.dart';
import 'package:fyp_hbs/services/app_initializer.dart';

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
  // Label selection for applying to many trees
  List<Map<String, dynamic>> _labelOptions = [];
  String? _selectedLabelId;
  int _labelTreesCount = 0;
  List<Map<String, dynamic>> _labelTrees = [];
  // Which trees under the selected label are chosen for applying the agrochemical
  Set<String> _selectedTreeUuids = {};
  

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
    // fetch available labels for optional bulk-apply
    _fetchLabels();
  }

  @override
  void dispose() {
    descriptionController.dispose();
    agrochemicalController.dispose();
    super.dispose();
  }


  Future<void> _fetchAgrochemicalOptions() async {
    if (!mounted) return;
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
        if (!mounted) return;
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
      final mapped =
          local.map<Map<String, dynamic>>((row) {
            return {
              'uuid': (row['id'] ?? '').toString(),
              'name': row['agrochemical_name'] ?? 'Unknown',
            };
          }).toList();
      if (!mounted) return;
      setState(() {
        _agrochemicalOptions = mapped;
        _isDropdownLoading = false;
      });
      return;
    } catch (e) {
      if (!mounted) return;
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


  Future<void> _fetchLabels() async {
    try {
      final online = await ConnectivityHelper.hasInternetConnection();
      if (!online) return;
      final resp = await TreeApi.getLabels();
      List<Map<String, dynamic>> found = [];
      if (resp.containsKey('data') && resp['data'] is List) {
        found =
            (resp['data'] as List)
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                .toList();
      }
      setState(() {
        _labelOptions = found;
      });
    } catch (e) {
      print('⚠️ Failed to fetch labels: $e');
    }
  }

  Future<void> _fetchTreesForLabel(String labelId) async {
  setState(() {
    _labelTreesCount = 0;
    _labelTrees = [];
    _selectedTreeUuids = {};
  });

  try {
    final resp = await TreeApi.getTreesByLabel(labelId: labelId);

    List<Map<String, dynamic>> trees = [];

    if (resp.containsKey('data') && resp['data'] is Map) {
      final d = resp['data'];
      if (d.containsKey('trees') && d['trees'] is List) {
        trees = (d['trees'] as List)
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    setState(() {
      _labelTrees = trees;
      _labelTreesCount = trees.length;
      _selectedTreeUuids =
          trees.map((t) =>
              (t['uuid'] ?? t['tree_uuid'] ?? t['id'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toSet(); // default select all
    });
  } catch (e) {
    print('⚠️ Failed to fetch trees for label: $e');
  }
}
 
String _extractTreeTag(Map<String, dynamic> t) {
  return (t['tree_tag'] ?? t['treeTag'] ?? t['tag'] ?? t['treeTagName'] ?? t['name'] ?? '').toString();
}

Future<void> _showTreeSelectionDialog() async {
  final selected = Set<String>.from(_selectedTreeUuids);

  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Select Trees'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _labelTrees.length,
            itemBuilder: (context, index) {
              final t = _labelTrees[index];
              final uuid =
                  (t['uuid'] ?? t['tree_uuid'] ?? t['id'] ?? '').toString();
              final tag = _extractTreeTag(t);

              return CheckboxListTile(
                value: selected.contains(uuid),
                title: Text(tag.isNotEmpty ? tag : uuid),
                onChanged: (val) {
                  if (val == true) {
                    selected.add(uuid);
                  } else {
                    selected.remove(uuid);
                  }
                  (context as Element).markNeedsBuild();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedTreeUuids = selected;
              });
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      );
    },
  );
}

  Future<void> _saveLocally(
    String formattedDate, {
    int synced = 0,
    String? treeUuid,
  }) async {
    final selectedName =
        _agrochemicalOptions
            .firstWhere(
              (e) => (e['uuid'] ?? e['id'] ?? '') == selectedAgrochemicalUuid,
              orElse: () => {'name': 'Unknown'},
            )['name']
            ?.toString();

    final model = AgrochemicalModel(
      tree_uuid: treeUuid ?? widget.treeUuid,
      agrochemicalId: selectedAgrochemicalUuid,
      agrochemicalName: selectedName,
      applied_at: formattedDate,
      description: descriptionController.text,
      synced: synced,
      pendingUpdate: widget.agrochemicalRecord != null ? 1 : 0,
    );

    try {
      await AgroDB().insertAgrochemical(model);
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
      lastDate: now,
    );
    if (picked != null) {
      setState(() => appliedAt = picked);
    }
  }

  Future<void> _saveRecord() async {
    // If user typed an agrochemical name into the DropdownMenu controller
    // (instead of selecting from the list), try to resolve it to a UUID
    // so validation can proceed.
    if (selectedAgrochemicalUuid == null &&
        agrochemicalController.text.trim().isNotEmpty) {
      final typed = agrochemicalController.text.trim().toLowerCase();
      final matches =
          _agrochemicalOptions
              .where((e) => (e['name'] ?? '').toString().toLowerCase() == typed)
              .toList();
      if (matches.isNotEmpty) {
        setState(
          () =>
              selectedAgrochemicalUuid =
                  (matches.first['uuid'] ?? matches.first['id'] ?? '')
                      .toString(),
        );
      }
    }

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
            if (_selectedLabelId != null && _selectedLabelId!.isNotEmpty) {
              // Apply to all trees under the selected label
              int success = 0;
              int failed = 0;
              for (final t in _labelTrees) {
                final treeUuid =
                    (t['uuid'] ?? t['tree_uuid'] ?? t['id'] ?? '').toString();
                if (treeUuid.isEmpty) continue;
                try {
                  await AgrochemicalApi.createAgrochemicalRecord(
                    tree_uuid: treeUuid,
                    agrochemical_uuid: selectedAgrochemicalUuid!,
                    applied_at: formattedDate,
                    description: descriptionController.text,
                  );
                  // Save locally as synced
                  await _saveLocally(
                    formattedDate,
                    synced: 1,
                    treeUuid: treeUuid,
                  );
                  success += 1;
                } catch (e) {
                  // on failure, save locally as pending
                  await _saveLocally(
                    formattedDate,
                    synced: 0,
                    treeUuid: treeUuid,
                  );
                  failed += 1;
                  print(
                    '⚠️ Failed creating agro record for tree $treeUuid: $e',
                  );
                }
              }

              await Flushbar(
                message: 'Applied to $success trees (${failed} failures)',
                icon: const Icon(Icons.check_circle, color: Colors.white),
                backgroundColor:
                    failed == 0
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                duration: const Duration(seconds: 2),
                borderRadius: BorderRadius.circular(12),
                margin: const EdgeInsets.all(12),
                flushbarPosition: FlushbarPosition.TOP,
              ).show(context);
            } else {
              // Single-tree create
              await AgrochemicalApi.createAgrochemicalRecord(
                tree_uuid: widget.treeUuid,
                agrochemical_uuid: selectedAgrochemicalUuid!,
                applied_at: formattedDate,
                description: descriptionController.text,
              );
              // Save locally with synced=1 since it was just created on server
              await _saveLocally(formattedDate, synced: 1);
              await Flushbar(
                message: 'Agrochemical record created successfully',
                icon: const Icon(Icons.check_circle, color: Colors.white),
                backgroundColor: Colors.green.shade700,
                duration: const Duration(seconds: 2),
                borderRadius: BorderRadius.circular(12),
                margin: const EdgeInsets.all(12),
                flushbarPosition: FlushbarPosition.TOP,
              ).show(context);
            }
          } else {
            // UPDATE remotely
            await AgrochemicalApi.updateAgrochemicalRecord(
              tree_uuid: widget.treeUuid,
              record_uuid: widget.agrochemicalRecord!['uuid'],
              agrochemical_uuid: selectedAgrochemicalUuid!,
              applied_at: formattedDate,
              description: descriptionController.text,
            );
            // Save locally with synced=1 since it was just updated on server
            await _saveLocally(formattedDate, synced: 1);
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
          print(
            '⚠️ Remote agrochemical save failed, saving locally instead: $e',
          );
          // fall through to local save below - save with synced=0 since it needs to sync
          await _saveLocally(formattedDate, synced: 0);
          await Flushbar(
            message:
                'Agrochemical record saved locally. Sync will occur when online',
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
      } else {
        // Offline: save locally with synced=0 (needs syncing)
        if (_selectedLabelId != null && _selectedLabelId!.isNotEmpty) {
          final targets = _labelTrees.where((t) {
            final treeUuid = (t['uuid'] ?? t['tree_uuid'] ?? t['id'] ?? '').toString();
            return treeUuid.isNotEmpty && _selectedTreeUuids.contains(treeUuid);
          }).toList();
          for (final t in targets) {
            final treeUuid = (t['uuid'] ?? t['tree_uuid'] ?? t['id'] ?? '').toString();
            if (treeUuid.isEmpty) continue;
            await _saveLocally(formattedDate, synced: 0, treeUuid: treeUuid);
          }
          await Flushbar(
            message:
                'Agrochemical saved locally for ${_selectedTreeUuids.length} trees. Sync will occur when online',
            icon: const Icon(Icons.cloud_off, color: Colors.white),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 2),
            borderRadius: BorderRadius.circular(12),
            margin: const EdgeInsets.all(12),
            flushbarPosition: FlushbarPosition.TOP,
          ).show(context);
        } else {
          await _saveLocally(formattedDate, synced: 0);
          await Flushbar(
            message:
                'Agrochemical application saved locally. Sync will occur when online',
            icon: const Icon(Icons.cloud_off, color: Colors.white),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 2),
            borderRadius: BorderRadius.circular(12),
            margin: const EdgeInsets.all(12),
            flushbarPosition: FlushbarPosition.TOP,
          ).show(context);
        }

        // Print pending sync counts
        await AppInitializer.printPendingSyncCounts();
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
          isEdit ? 'Edit Agro Record' : 'Add Agro Record',
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
              onPressed:
                  isLoading
                      ? null
                      : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Delete Record'),
                                content: const Text(
                                  'Are you sure you want to delete this agrochemical record?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, true),
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
                            await Flushbar(
                              message: 'Agrochemical record deleted',
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
                          } catch (e) {
                            await Flushbar(
                              message: 'Error deleting record: $e',
                              icon: const Icon(
                                Icons.error,
                                color: Colors.white,
                              ),
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

              // Pre-filled tree tag or multiple tags when a label is selected
              InkWell(
                onTap: () async {
                  // If a label is selected, allow picking specific trees
                  if (_selectedLabelId != null && _selectedLabelId!.isNotEmpty) {
                    await _showTreeSelectionDialog();
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Tree Tag',
                    filled: true,
                    fillColor: AppColors.gray200,
                  ),
                  child: Builder(builder: (context) {
                    // If a label is selected, show the selected tree tags
                    if (_selectedLabelId != null && _selectedLabelId!.isNotEmpty) {
                      final selectedTrees = _labelTrees.where((t) {
                        final uuid = (t['uuid'] ?? t['tree_uuid'] ?? t['id'] ?? '').toString();
                        return _selectedTreeUuids.contains(uuid);
                      }).map((t) => _extractTreeTag(t)).where((s) => s.isNotEmpty).toList();
                      if (selectedTrees.isEmpty) return const Text('No trees selected');
                      // join all tags (truncate visually if too long)
                      final joined = selectedTrees.join(', ');
                      return Text(joined);
                    }

                    // fallback: show single tree tag passed into page
                    return Text(widget.treeTag);
                  }),
                ),
              ),

              const SizedBox(height: 16),

              // Replace with Material 3 DropdownMenu to match Create Tree styling
              LayoutBuilder(
                builder: (context, constraints) {
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
                      dropdownMenuEntries:
                          _agrochemicalOptions
                              .map<DropdownMenuEntry<String>>(
                                (item) => DropdownMenuEntry(
                                  value:
                                      (item['uuid'] ?? item['id'] ?? '')
                                          .toString(),
                                  label: item['name']?.toString() ?? 'Unknown',
                                ),
                              )
                              .toList(),
                      onSelected: (String? v) {
                        setState(() => selectedAgrochemicalUuid = v);
                      },
                    ),
                  );
                },
              ),

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

              // Label selector (optional) - apply to all trees under selected label
              if (_labelOptions.isNotEmpty) ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final menuWidth = constraints.maxWidth;
                    return SizedBox(
                      width: double.infinity,
                      child: DropdownMenu<String>(
                        width: max(menuWidth, 360),
                        menuHeight: 320,
                        initialSelection: _selectedLabelId,
                        label: const Text('Apply to Label (optional)'),
                        dropdownMenuEntries: [
                          const DropdownMenuEntry<String>(
                            value: '',
                            label: 'None (no label)',
                          ),
                          ..._labelOptions
                              .map<DropdownMenuEntry<String>>(
                                (item) => DropdownMenuEntry(
                                  value:
                                      (item['id'] ??
                                              item['label_id'] ??
                                              item['uuid'] ??
                                              '')
                                          .toString(),
                                  label:
                                      item['label'] ??
                                      item['name'] ??
                                      item['label_name']?.toString() ??
                                      'Label',
                                ),
                              )
                              .toList(),
                        ],
                                onSelected: (String? v) {
                                  setState(() => _selectedLabelId = v);
                                  if (v != null && v.isNotEmpty) {
                                    _fetchTreesForLabel(v);
                                  } else {
                                    // cleared label selection
                                    setState(() {
                                      _labelTrees = [];
                                      _labelTreesCount = 0;
                                      _selectedTreeUuids = {};
                                    });
                                  }
                                },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                        if (_selectedLabelId != null && _selectedLabelId!.isNotEmpty)
                          Text(
                            'This will apply to ${_selectedTreeUuids.length} trees',
                            style: const TextStyle(color: Colors.grey),
                          ),
                const SizedBox(height: 16),
              ],

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
                          'Save',
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
