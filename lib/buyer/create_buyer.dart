import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fyp_hbs/nav.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/buyer_api.dart';

class CreateBuyerPage extends StatefulWidget {
  final Map<String, dynamic>? buyer;
  const CreateBuyerPage({super.key, this.buyer});

  @override
  _CreateBuyerPageState createState() => _CreateBuyerPageState();
}

class _CreateBuyerPageState extends State<CreateBuyerPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.buyer != null) {
      final buyer = widget.buyer!;
      _companyNameController.text = buyer['company_name'] ?? '';
      _contactNameController.text = buyer['contact_name'] ?? '';
      _contactNumberController.text = buyer['contact_number']?.toString() ?? '';
      _emailController.text = buyer['email'] ?? '';
      _addressController.text = buyer['address'] ?? '';
    }
  }

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
        title: Text(
          widget.buyer == null ? 'Add Company' : 'Edit Company',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.pakistanGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () async {
              if (widget.buyer != null) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Company'),
                    content: const Text('Are you sure you want to delete this company?'),
                    backgroundColor: Colors.white,
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
                    await BuyerApi.deleteBuyer(widget.buyer!['id'].toString());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tree deleted successfully')),
                    );
                    Navigator.pop(context, 'deleted');
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting buyer: $e')),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No tree to delete')),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 40),
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
                      if (widget.buyer == null) {
                        // Create
                        await BuyerApi.createBuyer(
                          companyName: _companyNameController.text,
                          contactName: _contactNameController.text,
                          contactNumber: _contactNumberController.text,
                          email: _emailController.text,
                          address: _addressController.text,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Buyer created successfully!'),
                          ),
                        );
                        Navigator.pop(context, true);
                      } else {
                        // Update
                        await BuyerApi.updateBuyer(
                          buyerId: widget.buyer!['id'].toString(),
                          companyName: _companyNameController.text,
                          contactName: _contactNameController.text,
                          contactNumber: _contactNumberController.text,
                          email: _emailController.text,
                          address: _addressController.text,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Buyer updated successfully!'),
                          ),
                        );
                        Navigator.pop(context, 'edited');
                      }

                      
                    } catch (e) {
                      if (!mounted) return;
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
