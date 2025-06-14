import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fyp_hbs/services/user_api.dart';


Future<bool?> showAddUserSheet(BuildContext context) {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  String selectedRole = 'Worker';
  bool isActive = true; // default active
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          // Future<void> _pickImage() async {
          //   final pickedFile = await _picker.pickImage(
          //     source: ImageSource.gallery,
          //   );
          //   if (pickedFile != null) {
          //     setState(() {
          //       _selectedImage = File(pickedFile.path);
          //     });
          //   }
          // }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Add User",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // GestureDetector(
                //   onTap: _pickImage,
                //   child: CircleAvatar(
                //     radius: 40,
                //     backgroundColor: Colors.grey.shade300,
                //     backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                //     child: _selectedImage == null
                //         ? const Icon(Icons.add_a_photo, color: Colors.white, size: 30)
                //         : null,
                //   ),
                // ),
                // const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Name',
                        ),
                        validator:
                            (value) => value!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Phone Number',
                        ),
                        validator:
                            (value) => value!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Email (optional)',
                        ),
                        validator: (value) {
                          if (value!.isNotEmpty &&
                              !RegExp(
                                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                              ).hasMatch(value)) {
                            return 'Invalid email format';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Role',
                        ),
                        items:
                            ['Worker', 'Manager']
                                .map(
                                  (role) => DropdownMenuItem(
                                    value: role,
                                    child: Text(role),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedRole = value);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Is Active?",
                            style: TextStyle(fontSize: 16),
                          ),
                          Switch(
                            value: isActive,
                            activeColor: AppColors.pakistanGreen,
                            onChanged: (value) {
                              setState(() {
                                isActive = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppColors.pakistanGreen,
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(color: AppColors.pakistanGreen),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            try {
                              int roleId = selectedRole == 'Manager' ? 2 : 3;

                              await UserApi.createUser(
                                name: nameController.text,
                                phone: phoneController.text,
                                role_id: roleId,
                                email:
                                    emailController.text.isEmpty
                                        ? null
                                        : emailController.text,
                                isActive: isActive,
                              );

                              // Close the bottom sheet first
                              Navigator.of(context, rootNavigator: true).pop(true);

                              // Then show a success SnackBar
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "User added successfully. Default password: hosbadurian",
                                  ),
                                  duration: Duration(seconds: 4),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          }
                        },

                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.pakistanGreen,
                        ),
                        child: const Text(
                          "Add",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
