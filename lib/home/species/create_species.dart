import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/species_api.dart';
import 'package:fyp_hbs/home/species/model/species.dart';

class CreateSpeciesPage extends StatefulWidget {
  final Species? species;
  const CreateSpeciesPage({super.key, this.species});

  @override
  _CreateSpeciesPageState createState() => _CreateSpeciesPageState();
}

class _CreateSpeciesPageState extends State<CreateSpeciesPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  bool isLoading = false;

    @override
  void initState() {
    super.initState();
    if (widget.species != null) {
      nameController.text = widget.species!.name;
      codeController.text = widget.species!.code;
      descriptionController.text = widget.species!.description ?? '';
    }
  }

  void _submitForm() async {
  if (_formKey.currentState!.validate()) {
    setState(() {
      isLoading = true;
    });

    try {
      Map<String, dynamic> response;

      if (widget.species == null) {
        response = await SpeciesApi.createSpecies(
          name: nameController.text.trim(),
          code: codeController.text.trim(),
          description: descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
        );
      } else {
        response = await SpeciesApi.editSpecies(
          id: widget.species!.id.toString(),
          name: nameController.text.trim(),
          code: codeController.text.trim(),
          description: descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response["message"] ?? "Success")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
}

  @override
  Widget build(BuildContext context) {
        final isEditing = widget.species != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      // appBar: AppBar(
      //   title: Text(
      //     isEditing ? 'Edit Species' : 'Create Species',
      //     style: const TextStyle(fontWeight: FontWeight.bold),
      //   ),
      //   centerTitle: false,
      //   leading: const BackButton(),
      //   backgroundColor: AppColors.background,
      // ),
       appBar: AppBar(
         title: Text(
          isEditing ? 'Edit Species' : 'Create Species',
          style: const TextStyle(fontWeight: FontWeight.bold),
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
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Name',
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: codeController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Code',
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Enter code' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Description (optional)',
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.hunterGreen,
                ),
                child:
                    isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
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
