import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fyp_hbs/services/user_api.dart';

Future<bool?> showAddUserSheet(
  BuildContext context, {
  required Map<String, dynamic> user,
}) {
  final _formKey = GlobalKey<FormState>();
  bool isEditing = user.isNotEmpty;
  final nameController = TextEditingController(
    text: isEditing ? user['name'] ?? '' : '',
  );
  final phoneController = TextEditingController(
    text: isEditing ? user['phone'] ?? '' : '',
  );
  final emailController = TextEditingController(
    text: isEditing ? user['email'] ?? '' : '',
  );
  String selectedRole =
      isEditing && user['roles'] != null && user['roles'].isNotEmpty
          ? user['roles'][0]
          : 'Worker';
  bool isActive = isEditing ? (user['is_active'] == 1) : true;

  if (isEditing) {
    nameController.text = user['name'] ?? '';
    phoneController.text = user['phone'] ?? '';
    emailController.text = user['email'] ?? '';
    isActive = user['is_active'] == 1;
    if (user['roles'] != null && user['roles'].isNotEmpty) {
      selectedRole = user['roles'][0];
    }
  }

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
                Text(
                  isEditing ? "Edit User" : "Add User",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isEditing ? "Update" : "Add",
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),

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

                              if (isEditing) {
                                await UserApi.updateUser(
                                  userId: user['id'],
                                  name: nameController.text,
                                  phone: phoneController.text,
                                  email:
                                      emailController.text.isEmpty
                                          ? null
                                          : emailController.text,
                                  isActive: isActive,
                                  role_id: roleId,
                                );
                              } else {
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
                              }

                              Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pop(true);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEditing
                                        ? "User updated successfully"
                                        : "User added successfully. Default password: hosbadurian",
                                  ),
                                  duration: const Duration(seconds: 4),
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
