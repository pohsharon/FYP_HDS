import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/health_api.dart';
import 'package:fyp_hbs/services/disease_api.dart';
import 'package:fyp_hbs/tree/health/create_disease.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please complete the form')));
      return;
    }

    try {
      setState(() => isLoading = true);

      if (widget.existingRecord != null) {
        // update existing
        await HealthApi.updateHealthRecord(
          id: widget.existingRecord!['id'].toString(),
          treeUuid: widget.treeUuid,
          diseaseId: selectedDiseaseId!,
          date: dateController.text,
          status: selectedStatus!,
          treatment: treatmentController.text,
        );
      } else {
        // create new
        await HealthApi.createHealthRecord(
          treeUuid: widget.treeUuid,
          diseaseId: selectedDiseaseId!,
          date: dateController.text,
          status: selectedStatus!,
          treatment: treatmentController.text,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingRecord != null
                ? 'Health record updated successfully'
                : 'Health record saved successfully',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                future: HealthApi.fetchDiseases(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final diseaseList = snapshot.data!;

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
}
