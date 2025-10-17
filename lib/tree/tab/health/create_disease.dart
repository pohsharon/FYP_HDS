import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/disease_api.dart';
import 'package:another_flushbar/flushbar.dart';

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

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill if editing
    if (widget.disease != null) {
      final d = widget.disease!;
      diseaseNameController.text = d['diseaseName']?.toString() ?? '';
      symptomsController.text = d['symptoms']?.toString() ?? '';
      remarksController.text = d['remarks']?.toString() ?? '';
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

      if (widget.disease == null) {
        // CREATE mode
        await DiseaseApi.createDisease(
          diseaseName: diseaseNameController.text,
          symptoms: symptomsController.text,
          remarks: remarksController.text,
        );
      } else {
        // UPDATE mode
        await DiseaseApi.updateDisease(
          id: widget.disease!['id'].toString(),
          diseaseName: diseaseNameController.text,
          symptoms: symptomsController.text,
          remarks: remarksController.text,
        );
      }

      await Flushbar(
        message: "Health record updated successfully",
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteDisease() async {
    if (widget.disease == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No disease to delete')));
      return;
    }

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
        await DiseaseApi.deleteDisease(widget.disease!['id'].toString());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disease deleted successfully')),
        );
        Navigator.pop(context); // close page
        Navigator.pop(context, true); // refresh parent
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting disease: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.disease != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Disease' : 'Add Disease',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.pakistanGreen,
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteDisease,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
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
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child:
                    isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                          isEditing ? 'Update Disease' : 'Save',
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
