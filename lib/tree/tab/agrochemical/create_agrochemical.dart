import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/agrochemical_api.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading agrochemicals: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    try {
      setState(() => isLoading = true);

      final formattedDate = DateFormat('yyyy-MM-dd').format(appliedAt!);

      if (widget.agrochemicalRecord == null) {
        // CREATE
        await AgrochemicalApi.createAgrochemicalRecord(
          tree_uuid: widget.treeUuid,
          agrochemical_uuid: selectedAgrochemicalUuid!,
          applied_at: formattedDate,
          description: descriptionController.text,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agrochemical record created successfully'),
          ),
        );
      } else {
        // UPDATE (need update API in AgrochemicalApi)
        await AgrochemicalApi.updateAgrochemicalRecord(
          tree_uuid: widget.treeUuid,
          record_uuid: widget.agrochemicalRecord!['uuid'],
          agrochemical_uuid: selectedAgrochemicalUuid!,
          applied_at: formattedDate,
          description: descriptionController.text,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agrochemical record updated successfully'),
          ),
        );
      }

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
    final isEdit = widget.agrochemicalRecord != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Agrochemical Record' : 'Add Agrochemical Record',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.pakistanGreen,
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
