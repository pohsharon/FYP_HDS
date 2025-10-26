import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/tree_api.dart';
import '../config.dart';
import 'package:another_flushbar/flushbar.dart';

class CreateTreePage extends StatefulWidget {
  final Map<String, dynamic>? tree;

  const CreateTreePage({super.key, this.tree});

  @override
  _CreateTreePageState createState() => _CreateTreePageState();
}

class _CreateTreePageState extends State<CreateTreePage> {
  final _formKey = GlobalKey<FormState>();
  final plantingDateController = TextEditingController();
  final heightController = TextEditingController();
  final widthController = TextEditingController();
  final floweringPeriodController = TextEditingController();

  List<Map<String, dynamic>> speciesList = [];
  String? selectedSpeciesId;

  File? _selectedImage;
  String? _existingThumbnailPath;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSpecies().then((_) {
      if (widget.tree != null) {
        final tree = widget.tree!;
        plantingDateController.text = tree['planted_at'] ?? '';
        heightController.text = tree['height']?.toString() ?? '';
        widthController.text = tree['width']?.toString() ?? '';
        floweringPeriodController.text =
            tree['flowering_period']?.toString() ?? '';
        selectedSpeciesId = tree['species']?['id']?.toString();
        _existingThumbnailPath = tree['thumbnail'];
      }
    });
  }

  Future<void> _fetchSpecies() async {
    try {
      final fetchedSpecies = await TreeApi.fetchSpecies();
      setState(() {
        speciesList = fetchedSpecies;
        if (speciesList.isNotEmpty) {
          selectedSpeciesId = speciesList.first['id'].toString();
        }
      });
    } catch (e) {
      Flushbar(
        message: 'Error fetching species: $e',
        icon: const Icon(Icons.error, color: Colors.white),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
        borderRadius: BorderRadius.circular(8),
        margin: const EdgeInsets.all(12),
      ).show(context);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 20,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveTree() async {
    if (!_formKey.currentState!.validate() || selectedSpeciesId == null) {
      return;
    }

    try {
      setState(() => isLoading = true);

      if (widget.tree == null) {
        // Create
        await TreeApi.createTree(
          speciesId: selectedSpeciesId!,
          plantedAt: plantingDateController.text,
          height: double.parse(heightController.text),
          diameter: double.parse(widthController.text),
          floweringPeriod: floweringPeriodController.text,
          imageFile: _selectedImage,
        );
      } else {
        // Update
        await TreeApi.updateTree(
          id: widget.tree!['id'].toString(),
          speciesId: selectedSpeciesId!,
          plantedAt: plantingDateController.text,
          height: double.parse(heightController.text),
          diameter: double.parse(widthController.text),
          floweringPeriod: floweringPeriodController.text,
          imageFile: _selectedImage, // Only send if user picks new
        );
      }

      await Flushbar(
        message:
            widget.tree == null
                ? 'Tree created successfully'
                : 'Tree updated successfully',
        icon: const Icon(Icons.check_circle, color: Colors.white),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
        borderRadius: BorderRadius.circular(12),
        margin: const EdgeInsets.all(12),
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);

      Future.microtask(() {
        if (!mounted) return;
        Navigator.pop(context, true);
      });
    } catch (e) {
      Flushbar(
        message: 'Error: $e',
        icon: const Icon(Icons.error, color: Colors.white),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
        borderRadius: BorderRadius.circular(8),
        margin: const EdgeInsets.all(12),
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
          widget.tree != null ? 'Edit Tree' : 'Add Tree',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.pakistanGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () async {
              if (widget.tree != null) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Delete Tree'),
                        content: const Text(
                          'Are you sure you want to delete this tree?',
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
                    await TreeApi.deleteTree(widget.tree!['id'].toString());

                    // show flushbar and wait for it to finish before navigating
                    await Flushbar(
                      message: 'Tree deleted successfully',
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      backgroundColor: Colors.green.shade700,
                      duration: const Duration(seconds: 2),
                      borderRadius: BorderRadius.circular(12),
                      margin: const EdgeInsets.all(12),
                      flushbarPosition: FlushbarPosition.TOP,
                    ).show(context);

                    if (!mounted) return;
                    Navigator.pop(context);
                    Navigator.pop(context, true);
                  } catch (e) {
                    await Flushbar(
                      message: 'Error deleting tree: $e',
                      icon: const Icon(Icons.error, color: Colors.white),
                      backgroundColor: Colors.red.shade700,
                      duration: const Duration(seconds: 3),
                      borderRadius: BorderRadius.circular(8),
                      margin: const EdgeInsets.all(12),
                    ).show(context);
                  }
                }
              } else {
                await Flushbar(
                  message: 'No tree to delete',
                  icon: const Icon(Icons.info, color: Colors.white),
                  backgroundColor: Colors.grey.shade700,
                  duration: const Duration(seconds: 2),
                  borderRadius: BorderRadius.circular(8),
                  margin: const EdgeInsets.all(12),
                ).show(context);
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
              _buildImagePreview(),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: selectedSpeciesId,
                onChanged: (value) {
                  setState(() {
                    selectedSpeciesId = value!;
                  });
                },
                items:
                    speciesList.map<DropdownMenuItem<String>>((species) {
                      return DropdownMenuItem<String>(
                        value: species['id'].toString(),
                        child: Text(species['name']),
                      );
                    }).toList(),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Species',
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator:
                    (value) => value == null ? 'Please select a species' : null,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: plantingDateController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Planting Date',
                  suffixIcon: Icon(Icons.calendar_today),
                  filled: true,
                  fillColor: Colors.white,
                ),
                readOnly: true,
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    plantingDateController.text = DateFormat(
                      'yyyy-MM-dd',
                    ).format(pickedDate);
                  }
                },
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Please pick a date'
                            : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: heightController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Initial Height (m)',
                  hintText: 'e.g. 2.5',
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Enter height' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: widthController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Initial Width (m)',
                  hintText: 'e.g. 1.6',
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Enter width' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: floweringPeriodController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Flowering Period',
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Enter flowering period'
                            : null,
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: isLoading ? null : _saveTree,
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
                        child: const Center(child: Text('Tap to select image')),
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

  String _buildFullImageUrl(String path) {
    final baseUrl = Config.supabaseBaseUrl;
    return '$baseUrl/$path';
  }
}
