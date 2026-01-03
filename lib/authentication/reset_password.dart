import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/nav.dart';
import 'package:another_flushbar/flushbar.dart';

class ResetPasswordPage extends StatefulWidget {
  final bool fromSettings;

  const ResetPasswordPage({super.key, this.fromSettings = false});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _hideOld = true;
  bool _hideNew = true;
  bool _hideConfirm = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
         "Reset Password",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.pakistanGreen,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.fromSettings) ...[
                  const SizedBox(height: 10),
                  _buildPasswordField(
                    "Old Password",
                    oldPasswordController,
                    _hideOld,
                    () => setState(() => _hideOld = !_hideOld),
                  ),
                  const SizedBox(height: 24),
                ],

                _buildPasswordField(
                  "New Password",
                  newPasswordController,
                  _hideNew,
                  () => setState(() => _hideNew = !_hideNew),
                ),
                const SizedBox(height: 24),

                _buildPasswordField(
                  "Confirm Password",
                  confirmPasswordController,
                  _hideConfirm,
                  () => setState(() => _hideConfirm = !_hideConfirm),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final valid = _formKey.currentState?.validate() ?? false;
                      if (!valid) {
                        Flushbar(
                          message: 'Please fill in all required fields correctly.',
                          icon: const Icon(Icons.error, color: Colors.white),
                          backgroundColor: Colors.red.shade700,
                          duration: const Duration(seconds: 3),
                          borderRadius: BorderRadius.circular(8),
                          margin: const EdgeInsets.all(12),
                        ).show(context);
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Nav(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.hunterGreen,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller,
    bool obscure,
    VoidCallback toggle,
  ) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter $label';
        if (label == "Confirm Password" &&
            value != newPasswordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }
}
