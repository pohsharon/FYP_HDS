import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/nav.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:fyp_hbs/services/api/auth_service.dart';

class ResetPasswordPage extends StatefulWidget {
  final bool fromSettings;
  final String? phone;

  const ResetPasswordPage({
    super.key,
    this.fromSettings = false,
    this.phone,
  });

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
                    onPressed: () async {
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

                      // Show loading
                      Flushbar(
                        message: 'Resetting password...',
                        icon: const Icon(Icons.sync, color: Colors.white),
                        backgroundColor: AppColors.hunterGreen,
                        duration: const Duration(seconds: 2),
                        borderRadius: BorderRadius.circular(8),
                        margin: const EdgeInsets.all(12),
                      ).show(context);

                      // Call reset password API
                      final result = await AuthService.resetPassword(
                        widget.phone ?? '',
                        newPasswordController.text,
                        confirmPasswordController.text,
                      );

                      if (result['success'] == true) {
                        // Password reset successfully
                        Flushbar(
                          message: result['message'] ?? 'Password reset successfully',
                          icon: const Icon(Icons.check_circle, color: Colors.white),
                          backgroundColor: Colors.green.shade700,
                          duration: const Duration(seconds: 2),
                          borderRadius: BorderRadius.circular(8),
                          margin: const EdgeInsets.all(12),
                        ).show(context);

                        // Navigate to login or main page
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Nav(),
                          ),
                          (route) => false,
                        );
                      } else {
                        // Show error
                        Flushbar(
                          message: result['message'] ?? 'Password reset failed',
                          icon: const Icon(Icons.error, color: Colors.white),
                          backgroundColor: Colors.red.shade700,
                          duration: const Duration(seconds: 3),
                          borderRadius: BorderRadius.circular(8),
                          margin: const EdgeInsets.all(12),
                        ).show(context);
                      }
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
