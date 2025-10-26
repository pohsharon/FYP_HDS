import 'dart:io';

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/health_api.dart';
import 'package:fyp_hbs/services/disease_api.dart';
import 'package:fyp_hbs/tree/tab/health/create_disease.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fyp_hbs/config.dart';

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

  File? _selectedImage;
  String? _existingThumbnailPath;

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
      selectedDiseaseId = record['disease']?['id'];
      selectedStatus = record['status'];
      _existingThumbnailPath = record['thumbnail'];
    }
  }

  Future<void> _saveHealthInfo() async {
    if (!_formKey.currentState!.validate()) {
      // show a flushbar instead of snackbar for consistency
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

    try {
      setState(() => isLoading = true);

      if (widget.existingRecord != null) {
        // update existing (optionally support image updates later)
        await HealthApi.updateHealthRecord(
          id: widget.existingRecord!['id'].toString(),
          treeUuid: widget.treeUuid,
          diseaseId: selectedDiseaseId!,
          date: dateController.text,
          status: selectedStatus!,
          treatment: treatmentController.text,
          imageFile: _selectedImage,
        );
      } else {
        // create new
        await HealthApi.createHealthRecord(
          treeUuid: widget.treeUuid,
          diseaseId: selectedDiseaseId!,
          date: dateController.text,
          status: selectedStatus!,
          treatment: treatmentController.text,
          imageFile: _selectedImage,
        );
      }

      // show success flushbar, then pop with result
      await Flushbar(
        message:
            widget.existingRecord != null
                ? 'Health record updated successfully.'
                : 'Health record created successfully.',
        icon: const Icon(Icons.check_circle, color: Colors.white),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
        borderRadius: BorderRadius.circular(12),
        margin: const EdgeInsets.all(12),
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);

      if (!mounted) return;
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60, // increased a bit; adjust as needed
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  String _buildFullImageUrl(String path) {
    final baseUrl = Config.supabaseBaseUrl;
    return '$baseUrl/$path';
  }

  Widget _buildImagePreview() {
    // Use a fixed height container and Stack to allow the close button
    return GestureDetector(
      onTap: _pickImage,
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
                      : (_existingThumbnailPath != null &&
                          _existingThumbnailPath!.isNotEmpty)
                      ? Image.network(
                        _buildFullImageUrl(_existingThumbnailPath!), // ✅ FIXED
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
                        child: const Center(
                          child: Text('Tap to select image'),
                        ),
                      ),
            ),

            if (_selectedImage != null ||
                (_existingThumbnailPath != null &&
                    _existingThumbnailPath!.isNotEmpty))
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedImage = null;
                      _existingThumbnailPath = null; // clear preview
                    });
                  },
                  child: const CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRecord() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Health record'),
        content: const Text('Are you sure you want to delete this health record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => isLoading = true);
      await HealthApi.deleteHealthRecord(widget.existingRecord!['id'].toString());
      await Flushbar(
        message: 'Health record deleted',
        icon: const Icon(Icons.check_circle, color: Colors.white),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
        borderRadius: BorderRadius.circular(12),
        margin: const EdgeInsets.all(12),
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      await Flushbar(
        message: 'Error deleting health record: $e',
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
        actions: [
          if (widget.existingRecord != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteRecord,
            ),
        ],
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
                        initialDate:
                            DateTime.tryParse(dateController.text) ??
                            DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        builder: (BuildContext context, Widget? child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: const ColorScheme.light(
                                primary:
                                    AppColors.pakistanGreen, // header color
                                onPrimary: Colors.white, // header text color
                                onSurface: Colors.black, // body text color
                              ),
                              dialogBackgroundColor:
                                  Colors.white, // background color
                            ),
                            child: child!,
                          );
                        },
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
                    dropdownColor: Colors.white,
                    value: selectedDiseaseId?.toString(),
                    items: [
                      ...diseaseList.map((d) {
                        return DropdownMenuItem<String>(
                          value: d['id']?.toString(),
                          child: Text(d['diseaseName'] ?? ''),
                        );
                      }).toList(),
                      const DropdownMenuItem<String>(
                        value: 'new',
                        child: Text('Add New Disease'),
                      ),
                    ],
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
                        setState(() {}); // reload after creating new disease
                      } else if (value != null) {
                        setState(() => selectedDiseaseId = int.tryParse(value));
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
                dropdownColor: Colors.white,
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
