import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/disease_api.dart';

class CreateDiseasePage extends StatefulWidget {
  final Map<String, dynamic>? disease;
  final String treeTag;
  final String treeUuid;

  const CreateDiseasePage({
    super.key,
    this.disease,
    required this.treeTag,
    required this.treeUuid,
  });

  @override
  _CreateDiseasePageState createState() => _CreateDiseasePageState();
}

class _CreateDiseasePageState extends State<CreateDiseasePage> {
  final _formKey = GlobalKey<FormState>();
  final diseaseNameController = TextEditingController();
  final symptomsController = TextEditingController();
  final remarksController = TextEditingController();

  List<Map<String, dynamic>> speciesList = [];
  String? selectedSpeciesId;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.disease != null) {
      final disease = widget.disease!;
      diseaseNameController.text = disease['disease'] ?? '';
      symptomsController.text = disease['symptoms']?.toString() ?? '';
      remarksController.text = disease['remarks']?.toString() ?? '';
    }
  }

  Future<void> _saveDisease() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please complete the form')));
      return;
    }

    try {
      setState(() => isLoading = true);

      print({
        "diseaseName": diseaseNameController.text,
        "symptoms": symptomsController.text,
        "remarks": remarksController.text,
      });

      if (widget.disease == null) {
        await DiseaseApi.createDisease(
          diseaseName: diseaseNameController.text,
          symptoms: symptomsController.text,
          remarks: remarksController.text,
        );
      } else {
        await DiseaseApi.updateDisease(
          diseaseName: diseaseNameController.text,
          symptoms: symptomsController.text,
          remarks: remarksController.text,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.disease == null
                ? 'Disease created successfully'
                : 'Disease updated successfully',
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
        title: Text(
          widget.disease != null ? 'Edit Disease' : 'Add Disease',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.pakistanGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () async {
              if (widget.disease != null) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Delete Disease'),
                        content: const Text(
                          'Are you sure you want to delete this disease?',
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
                    await DiseaseApi.deleteDisease(
                      widget.disease!['id'].toString(),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Disease deleted successfully'),
                      ),
                    );
                    Navigator.pop(context);
                    Navigator.pop(context, true);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting disease: $e')),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No disease to delete')),
                );
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
              TextFormField(
                controller: diseaseNameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Disease Name',
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Enter disease name'
                            : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: symptomsController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Symptoms',
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Enter symptoms'
                            : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: remarksController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Remarks',
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Enter remarks' : null,
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: isLoading ? null : _saveDisease,
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
