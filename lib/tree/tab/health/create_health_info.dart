import 'dart:io';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/health_api.dart';
import 'package:fyp_hbs/services/api/disease_api.dart';
import 'package:fyp_hbs/utils/connectivity_helper.dart';
import 'package:fyp_hbs/services/local database/disease_db.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:fyp_hbs/models/health_model.dart';
import 'package:fyp_hbs/services/local database/health_db.dart';
import 'package:fyp_hbs/tree/tab/health/create_disease.dart';
import 'package:fyp_hbs/services/app_initializer.dart';
import '../../../config.dart';

class CreateHealthInfoPage extends StatefulWidget {
  final String treeTag;
  final String treeUuid;
  final Map<String, dynamic>? existingRecord;

  const CreateHealthInfoPage({
    super.key,
    required this.treeTag,
    required this.treeUuid,
    required this.existingRecord,
  });

  @override
  _CreateHealthInfoPageState createState() => _CreateHealthInfoPageState();
}

class _CreateHealthInfoPageState extends State<CreateHealthInfoPage> {
  final _formKey = GlobalKey<FormState>();

  final dateController = TextEditingController();
  final treatmentController = TextEditingController();
  final diseaseController = TextEditingController();
  final statusController = TextEditingController();

  int? selectedDiseaseId;
  String? selectedStatus;
  bool isLoading = false;
  File? _selectedImage;
  String? _existingThumbnail;
  Future<List<Map<String, dynamic>>>? _diseaseFuture;

  @override
  void dispose() {
    dateController.dispose();
    treatmentController.dispose();
    diseaseController.dispose();
    statusController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _diseaseFuture = _loadDiseases();

    if (widget.existingRecord != null) {
      final record = widget.existingRecord!;
      dateController.text = record['recorded_at'] ?? '';
      treatmentController.text = record['treatment'] ?? '';
      selectedDiseaseId = record['disease']['id'];
      selectedStatus = record['status'];
      diseaseController.text = selectedDiseaseId?.toString() ?? '';
      statusController.text = selectedStatus ?? '';
      _existingThumbnail = record['thumbnail']?.toString();
    }
  }

  Future<void> _pickImage() async {
    final online = await ConnectivityHelper.hasInternetConnection();
    if (!online) {
      await Flushbar(
        message: 'No internet — cannot pick image while offline',
        icon: const Icon(Icons.cloud_off, color: Colors.white),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 2),
        borderRadius: BorderRadius.circular(12),
        margin: const EdgeInsets.all(12),
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  Future<void> _saveHealthInfo() async {
    if (!_formKey.currentState!.validate()) {
      await Flushbar(
        message: 'Please complete the form',
        icon: const Icon(Icons.error, color: Colors.white),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 2),
        borderRadius: BorderRadius.circular(8),
        margin: const EdgeInsets.all(12),
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
      return;
    }

    setState(() => isLoading = true);
    try {
      // Resolve diseaseName for local storage (best-effort)
      String? diseaseName;
      try {
        final all = await DiseaseDB().getAllDiseases();
        final match = all.firstWhere(
          (d) => (d['id']?.toString() ?? '') == (selectedDiseaseId?.toString() ?? ''),
          orElse: () => {},
        );
        if (match.isNotEmpty) diseaseName = match['disease_name'] ?? match['diseaseName'];
      } catch (_) {
        // ignore
      }

      final thumbnailPath = _selectedImage?.path ?? _existingThumbnail;

      final healthModel = HealthModel(
        tree_uuid: widget.treeUuid,
        diseaseId: selectedDiseaseId?.toString(),
        diseaseName: diseaseName,
        status: selectedStatus,
        recorded_at: dateController.text,
        treatment: treatmentController.text,
        thumbnail: thumbnailPath,
        synced: 0,
        pendingUpdate: 0,
        pendingDelete: 0,
      );

      final online = await ConnectivityHelper.hasInternetConnection();
      var savedLocally = false;
      Map<String, dynamic>? remoteData;

      if (online) {
        try {
          if (widget.existingRecord != null) {
            // Attempt remote update
            remoteData = await HealthApi.updateHealthRecord(
              id: widget.existingRecord!['id'].toString(),
              treeUuid: widget.treeUuid,
              diseaseId: int.parse(selectedDiseaseId!.toString()),
              date: dateController.text,
              status: selectedStatus!,
              treatment: treatmentController.text,
              imageFile: _selectedImage,
            );
          } else {
            // Attempt remote create
            remoteData = await HealthApi.createHealthRecord(
              treeUuid: widget.treeUuid,
              diseaseId: int.parse(selectedDiseaseId!.toString()),
              date: dateController.text,
              status: selectedStatus!,
              treatment: treatmentController.text,
              imageFile: _selectedImage,
            );
          }

          // Cache successful remote record locally so it is visible offline
          try {
            final rec = (remoteData['data'] is Map)
                ? Map<String, dynamic>.from(remoteData['data'])
                : (remoteData ?? <String, dynamic>{});
            final cached = healthModel.copyWith(
              id: (rec['id'] is int)
                  ? rec['id'] as int
                  : int.tryParse(rec['id']?.toString() ?? '') ?? int.tryParse(widget.existingRecord?['id']?.toString() ?? ''),
              thumbnail: rec['thumbnail']?.toString() ?? _selectedImage?.path ?? _existingThumbnail,
              synced: 1,
              pendingUpdate: 0,
              pendingDelete: 0,
            );
            await HealthDB().insertHealth(cached);
          } catch (cacheErr) {
            print('⚠️ Failed to cache health locally after remote save: $cacheErr');
          }
        } catch (e) {
          // Remote call failed — save locally as pending
          print('⚠️ Health API failed, saving locally: $e');
          try {
            final toSave = widget.existingRecord != null
                ? healthModel.copyWith(pendingUpdate: 1)
                : healthModel;
            await HealthDB().insertHealth(toSave);
            savedLocally = true;
          } catch (insErr) {
            print('⚠️ Failed to save health locally after API failure: $insErr');
            rethrow;
          }
        }
      } else {
        // Offline: save locally and mark pending appropriately
        try {
          final toSave = widget.existingRecord != null
              ? healthModel.copyWith(pendingUpdate: 1)
              : healthModel;
          await HealthDB().insertHealth(toSave);
          savedLocally = true;
        } catch (insErr) {
          print('⚠️ Failed to save health locally while offline: $insErr');
          rethrow;
        }
      }

      // Notify user
      if (mounted) {
        if (online && !savedLocally) {
          await Flushbar(
            message: widget.existingRecord != null ? 'Health record updated successfully' : 'Health record saved successfully',
            icon: const Icon(Icons.check_circle, color: Colors.white),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
            borderRadius: BorderRadius.circular(12),
            margin: const EdgeInsets.all(12),
            flushbarPosition: FlushbarPosition.TOP,
          ).show(context);
        } else {
          final offlineMsg = widget.existingRecord != null
              ? 'Changes saved locally and will be synced when online'
              : 'Health record saved locally. Sync will occur when online';
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
        Navigator.pop(context, true);
      }
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.existingRecord == null ? 'Add Health Info' : 'Edit Health Info',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.pakistanGreen,
        actions: widget.existingRecord != null
            ? [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete health record?'),
                              content: const Text('This will remove the record permanently.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );

                          if (confirm != true) return;

                          final online = await ConnectivityHelper.hasInternetConnection();
                          if (!online) {
                            await Flushbar(
                              message: 'Cannot delete while offline',
                              backgroundColor: Colors.orange.shade700,
                              duration: const Duration(seconds: 2),
                              margin: const EdgeInsets.all(12),
                              borderRadius: BorderRadius.circular(8),
                            ).show(context);
                            return;
                          }

                          try {
                            setState(() => isLoading = true);
                            await HealthApi.deleteHealthRecord(
                              id: widget.existingRecord!['id'].toString(),
                            );
                            // Remove cached local copy if present. Try by id first,
                            // then fall back to matching tree_uuid+recorded_at+disease.
                            try {
                              await HealthDB().deleteHealthById(widget.existingRecord!['id']);
                            } catch (delErr) {
                              print('⚠️ delete by id failed: $delErr');
                            }
                            try {
                              final rec = widget.existingRecord!;
                              final recorded = rec['recorded_at']?.toString() ?? rec['recordedAt']?.toString() ?? '';
                              final did = (rec['disease'] is Map) ? (rec['disease']['id']?.toString() ?? '') : (rec['disease_id']?.toString() ?? rec['diseaseId']?.toString() ?? '');
                              if (recorded.isNotEmpty && did.isNotEmpty) {
                                await HealthDB().deleteHealthByMatch(
                                  treeUuid: widget.treeUuid,
                                  recordedAt: recorded,
                                  diseaseId: did,
                                );
                              }
                            } catch (matchErr) {
                              print('⚠️ delete by match failed: $matchErr');
                            }
                            if (!mounted) return;
                            await Flushbar(
                              message: 'Health record deleted',
                              icon: const Icon(Icons.check_circle, color: Colors.white),
                              backgroundColor: Colors.green.shade700,
                              duration: const Duration(seconds: 2),
                              borderRadius: BorderRadius.circular(12),
                              margin: const EdgeInsets.all(12),
                              flushbarPosition: FlushbarPosition.TOP,
                            ).show(context);
                            Navigator.pop(context, true);
                          } catch (e) {
                            await Flushbar(
                              message: 'Delete failed: $e',
                              backgroundColor: Colors.red.shade700,
                              duration: const Duration(seconds: 3),
                              margin: const EdgeInsets.all(12),
                              borderRadius: BorderRadius.circular(8),
                            ).show(context);
                          } finally {
                            if (mounted) setState(() => isLoading = false);
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
              _buildImagePreview(),
              const SizedBox(height: 16),

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

              TextFormField(
                controller: dateController,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'Date',
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        dateController.text = DateFormat(
                          'yyyy-MM-dd',
                        ).format(picked);
                      }
                    },
                  ),
                ),
                readOnly: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Select date';
                  final parsed = DateTime.tryParse(value);
                  if (parsed != null && parsed.isAfter(DateTime.now())) {
                    return 'Date cannot be in the future';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),


              FutureBuilder<List<Map<String, dynamic>>>(
                future: _diseaseFuture ??= _loadDiseases(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    // fallback to empty list on error
                    print('⚠️ _loadDiseases error: ${snapshot.error}');
                    return const Center(child: Text('Failed to load diseases'));
                  }
                  final diseaseList = snapshot.data ?? <Map<String, dynamic>>[];

                  return LayoutBuilder(builder: (context, constraints) {
                    final menuWidth = constraints.maxWidth;
                    return SizedBox(
                      width: double.infinity,
                      child: DropdownMenu<String>(
                        width: max(menuWidth, 360),
                        controller: diseaseController,
                        requestFocusOnTap: true,
                        initialSelection: selectedDiseaseId?.toString(),
                        label: const Text('Disease'),
                        dropdownMenuEntries: diseaseList
                            .map<DropdownMenuEntry<String>>(
                              (d) => DropdownMenuEntry(
                                value: d['id'].toString(),
                                label: d['diseaseName'] ?? '',
                              ),
                            )
                            .toList()
                          ..add(
                            const DropdownMenuEntry(value: 'new', label: 'Add New Disease'),
                          ),
                        onSelected: (String? v) async {
                          if (v == null) return;
                          if (v == 'new') {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateDiseasePage(
                                  treeTag: widget.treeTag,
                                  treeUuid: widget.treeUuid,
                                ),
                              ),
                            );
                            setState(() {});
                            return;
                          }
                          setState(() {
                            selectedDiseaseId = int.tryParse(v);
                            try {
                              final found = diseaseList.firstWhere((d) => d['id'].toString() == v);
                              diseaseController.text = found['diseaseName'] ?? '';
                            } catch (_) {
                              diseaseController.text = '';
                            }
                          });
                        },
                      ),
                    );
                  });
                },
              ),

              // helper to load diseases with offline fallback
              

              const SizedBox(height: 16),

              // Status Dropdown
              LayoutBuilder(builder: (context, constraints) {
                final menuWidth = constraints.maxWidth;
                return SizedBox(
                  width: double.infinity,
                  child: DropdownMenu<String>(
                    width: max(menuWidth, 360),
                    controller: statusController,
                    requestFocusOnTap: true,
                    initialSelection: selectedStatus,
                    label: const Text('Status'),
                    dropdownMenuEntries: ['Recovered', 'Severe', 'Medium']
                        .map<DropdownMenuEntry<String>>((status) => DropdownMenuEntry(value: status, label: status))
                        .toList(),
                    onSelected: (v) => setState(() => selectedStatus = v),
                  ),
                );
              }),
              const SizedBox(height: 16),

              // Treatment Field
              TextFormField(
                controller: treatmentController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Treatment',
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Optional notes...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: isLoading ? null : _saveHealthInfo,
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

  Future<List<Map<String, dynamic>>> _loadDiseases() async {
    // Try online first
    try {
      final online = await ConnectivityHelper.hasInternetConnection();
      if (online) {
        try {
          final remote = await DiseaseApi.fetchDiseases();
          // Ensure remote is in expected shape (id, diseaseName)
          return remote.map((e) {
            return {
              'id': e['id'],
              'diseaseName': e['diseaseName'] ?? e['disease_name'] ?? e['name'] ?? ''
            };
          }).toList();
        } catch (e) {
          print('⚠️ Remote disease fetch failed: $e');
        }
      }
    } catch (e) {
      print('⚠️ Connectivity check failed: $e');
    }

    // Fallback: load from local DB
    try {
      final local = await DiseaseDB().getAllDiseases();
      return local.map((e) {
        return {
          'id': e['id'],
          'diseaseName': e['disease_name'] ?? e['diseaseName'] ?? ''
        };
      }).toList();
    } catch (e) {
      print('⚠️ Failed to load diseases from local DB: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Widget _buildImagePreview() {
    return GestureDetector(
      onTap: isLoading ? null : _pickImage,
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child:
                  _selectedImage != null
                      ? Image.file(
                        _selectedImage!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                      : (_existingThumbnail != null && _existingThumbnail!.isNotEmpty)
                      ? Image.network(
                        _existingThumbnail!.startsWith('http')
                            ? _existingThumbnail!
                            : '${Config.supabaseBaseUrl}${_existingThumbnail!}',
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            height: 180,
                            width: double.infinity,
                            child: const Center(
                              child: Text('Image unavailable'),
                            ),
                          );
                        },
                      )
                      : Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: const Center(child: Text('Tap to select image')),
                      ),
            ),

            if (_selectedImage != null || (_existingThumbnail != null && _existingThumbnail!.isNotEmpty))
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedImage = null;
                      _existingThumbnail = null;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
