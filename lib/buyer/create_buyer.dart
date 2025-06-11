import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/buyer_api.dart';

class CreateBuyerPage extends StatefulWidget {
  const CreateBuyerPage({super.key});

  @override
  _CreateBuyerPageState createState() => _CreateBuyerPageState();
}

class _CreateBuyerPageState extends State<CreateBuyerPage> {
  final _formKey = GlobalKey<FormState>();
  // final ImagePicker _picker = ImagePicker();
  // File? _selectedImage;

  // Future<void> _pickImage() async {
  //   final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
  //   if (pickedFile != null) {
  //     setState(() {
  //       _selectedImage = File(pickedFile.path);
  //     });
  //   }
  // }

  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void dispose() {
    _companyNameController.dispose();
    _contactNameController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var items = ['Selangor', 'Kuala Lumpur', 'Penang', 'Johor'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Add Company',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        leading: const BackButton(),
        backgroundColor: AppColors.background,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Center(
              //   child: GestureDetector(
              //     onTap: _pickImage,
              //     child: CircleAvatar(
              //       radius: 50,
              //       backgroundColor: Colors.grey[300],
              //       backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
              //       child: _selectedImage == null
              //           ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
              //           : null,
              //     ),
              //   ),
              // ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Company Name',
                  hintText: 'Hosba Sdn Bhd',
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactNameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Contact Name',
                  hintText: 'eg. John Doe',
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactNumberController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Contact Number',
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Email',
                  hintText: 'eg. john.doe@example.com',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Address',
                  hintText: 'eg. Kuala Lumpur',
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    try {
                      final response = await BuyerApi.createBuyer(
                        companyName: _companyNameController.text,
                        contactName: _contactNameController.text,
                        contactNumber: _contactNumberController.text,
                        email: _emailController.text,
                        address: _addressController.text,
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Buyer created successfully!'),
                          ),
                        );
                        Navigator.pop(context); // or clear form
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  }
                },

                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004225),
                ),
                child: const Text(
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
