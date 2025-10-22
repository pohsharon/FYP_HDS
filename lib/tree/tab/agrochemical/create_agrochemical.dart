import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/agrochemical_api.dart';
import 'package:another_flushbar/flushbar.dart';

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

  bool isLoading = false;
  List<Map<String, dynamic>> _agrochemicalOptions = [];
  bool _isDropdownLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAgrochemicalOptions();
    if (widget.agrochemicalRecord != null) {
      final record = widget.agrochemicalRecord!;
      selectedAgrochemicalUuid = record['agrochemical_uuid'];
      appliedAt = DateTime.tryParse(record['applied_at'] ?? '');
      descriptionController.text = record['description'] ?? '';
    }
  }

  Future<void> _fetchAgrochemicalOptions() async {
    try {
      final options = await AgrochemicalApi.getAgrochemical();
      setState(() {
        _agrochemicalOptions = options;
        _isDropdownLoading = false;
      });
    } catch (e) {
      setState(() => _isDropdownLoading = false);
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

  // ✅ DELETE with confirmation dialog
  Future<void> _deleteRecord() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record?'),
        content: const Text(
          'Are you sure you want to delete this agrochemical record?',
        ),
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

    if (confirm == true) {
      try {
        setState(() => isLoading = true);

        await AgrochemicalApi.deleteAgrochemicalRecord(
          widget.agrochemicalRecord!['uuid'],
        );

        if (!mounted) return;
        Navigator.pop(context, true); // Refresh previous page

        Flushbar(
          message: 'Agrochemical record deleted successfully',
          icon: const Icon(Icons.delete, color: Colors.white),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(12),
          borderRadius: BorderRadius.circular(8),
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      } catch (e) {
        Flushbar(
          message: 'Error deleting record: $e',
          icon: const Icon(Icons.error, color: Colors.white),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(12),
          borderRadius: BorderRadius.circular(8),
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  // ✅ SAVE (Create / Update)
  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate() ||
        selectedAgrochemicalUuid == null ||
        appliedAt == null) return;

    try {
      setState(() => isLoading = true);

      final formattedDate = DateFormat('yyyy-MM-dd').format(appliedAt!);

      if (widget.agrochemicalRecord == null) {
        await AgrochemicalApi.createAgrochemicalRecord(
          tree_uuid: widget.treeUuid,
          agrochemical_uuid: selectedAgrochemicalUuid!,
          applied_at: formattedDate,
          description: descriptionController.text,
        );
      } else {
        await AgrochemicalApi.updateAgrochemicalRecord(
          tree_uuid: widget.treeUuid,
          record_uuid: widget.agrochemicalRecord!['uuid'],
          agrochemical_uuid: selectedAgrochemicalUuid!,
          applied_at: formattedDate,
          description: descriptionController.text,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
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
        title: Text(isEdit ? 'Edit Agrochemical Record' : 'Add Agrochemical'),
        backgroundColor: AppColors.pakistanGreen,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: isLoading ? null : _deleteRecord,
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

              DropdownButtonFormField<String>(
                value: selectedAgrochemicalUuid,
                items:
                    _isDropdownLoading
                        ? [] // While loading, show nothing
                        : _agrochemicalOptions.map<DropdownMenuItem<String>>((
                          item,
                        ) {
                          return DropdownMenuItem<String>(
                            value: item['uuid'], // use uuid from API
                            child: Text(item['name'] ?? 'Unknown'),
                          );
                        }).toList(),
                onChanged:
                    (val) => setState(() => selectedAgrochemicalUuid = val),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Select Agrochemical',
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator:
                    (value) =>
                        value == null ? 'Please select an agrochemical' : null,
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
