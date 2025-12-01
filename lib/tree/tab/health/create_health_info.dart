import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/health_api.dart';
import 'package:fyp_hbs/services/api/disease_api.dart';
import 'package:fyp_hbs/utils/connectivity_helper.dart';
import 'package:fyp_hbs/services/local database/disease_db.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:fyp_hbs/models/health_model.dart';
import 'package:fyp_hbs/services/local database/health_db.dart';
import 'package:fyp_hbs/tree/tab/health/create_disease.dart';

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

  int? selectedDiseaseId;
  String? selectedStatus;
  bool isLoading = false;

  @override
  void dispose() {
    dateController.dispose();
    treatmentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    if (widget.existingRecord != null) {
      final record = widget.existingRecord!;
      dateController.text = record['recorded_at'] ?? '';
      treatmentController.text = record['treatment'] ?? '';
      selectedDiseaseId = record['disease']['id'];
      selectedStatus = record['status'];
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

      final healthModel = HealthModel(
        tree_uuid: widget.treeUuid,
        diseaseId: selectedDiseaseId?.toString(),
        diseaseName: diseaseName,
        status: selectedStatus,
        recorded_at: dateController.text,
        treatment: treatmentController.text,
        synced: 0,
        pendingUpdate: 0,
        pendingDelete: 0,
      );

      final online = await ConnectivityHelper.hasInternetConnection();
      var savedLocally = false;

      if (online) {
        try {
          if (widget.existingRecord != null) {
            // Attempt remote update
            await HealthApi.updateHealthRecord(
              id: widget.existingRecord!['id'].toString(),
              treeUuid: widget.treeUuid,
              diseaseId: int.parse(selectedDiseaseId!.toString()),
              date: dateController.text,
              status: selectedStatus!,
              treatment: treatmentController.text,
            );
          } else {
            // Attempt remote create
            await HealthApi.createHealthRecord(
              treeUuid: widget.treeUuid,
              diseaseId: int.parse(selectedDiseaseId!.toString()),
              date: dateController.text,
              status: selectedStatus!,
              treatment: treatmentController.text,
            );
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
              : 'Health record saved locally and will be synced when online';
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
        title: const Text(
          'Add Health Info',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.pakistanGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
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
                        lastDate: DateTime(2100),
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
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Select date' : null,
              ),
              const SizedBox(height: 16),


              FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadDiseases(),
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

                  return DropdownButtonFormField<String>(
                    value: selectedDiseaseId?.toString(),
                    items:
                        diseaseList.map((d) {
                            return DropdownMenuItem(
                              value: d['id'].toString(),
                              child: Text(d['diseaseName'] ?? ""),
                            );
                          }).toList()
                          ..add(
                            const DropdownMenuItem(
                              value: 'new',
                              child: Text('Add New Disease'),
                            ),
                          ),
                    onChanged: (value) async {
                      if (value == 'new') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => CreateDiseasePage(
                                  treeTag: widget.treeTag,
                                  treeUuid: widget.treeUuid,
                                ),
                          ),
                        );
                        setState(() {});
                      } else {
                        setState(() => selectedDiseaseId = int.parse(value!));
                      }
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Disease',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator:
                        (value) =>
                            value == null || value.isEmpty || value == 'new'
                                ? 'Select disease'
                                : null,
                  );
                },
              ),

              // helper to load diseases with offline fallback
              

              const SizedBox(height: 16),

              // Status Dropdown
              DropdownButtonFormField<String>(
                value: selectedStatus,
                items:
                    ['Recovered', 'Severe', 'Medium']
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => selectedStatus = value),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Status',
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Select status' : null,
              ),
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
}
