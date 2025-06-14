import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/tree_api.dart';

class CreateTreePage extends StatefulWidget {
  const CreateTreePage({super.key});

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
  String? _base64Image;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSpecies();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching species: $e')));
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });

      final bytes = await pickedFile.readAsBytes();
      _base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    }
  }

  Future<void> _saveTree() async {
    if (!_formKey.currentState!.validate() || selectedSpeciesId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please complete the form')));
      return;
    }

    try {
      setState(() => isLoading = true);

      final result = await TreeApi.createTree(
        speciesId: selectedSpeciesId!,
        plantedAt: plantingDateController.text,
        height: double.parse(heightController.text),
        diameter: double.parse(widthController.text),
        floweringPeriod: floweringPeriodController.text,
        imageBase64: _base64Image ?? "",
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tree created successfully')),
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
          'Add Tree',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        leading: const BackButton(),
        backgroundColor: AppColors.background,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child:
                    _selectedImage != null
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _selectedImage!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                        : Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: const Center(
                            child: Text('Tap to select tree image'),
                          ),
                        ),
              ),
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
                  labelText: 'Flowering Period (days)',
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
}
