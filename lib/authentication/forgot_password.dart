import 'package:flutter/material.dart';
import 'package:fyp_hbs/authentication/otp_verification.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String?
  _serverError; // For showing backend validation errors (e.g. phone not registered)
  bool _loading = false;

  Future<bool> isPhoneRegistered(String phone) async {
    final result = await AuthService.checkPhone(phone);
    final exists = (result['exists'] as bool?) ?? false;

    if (!exists) {
      setState(() {
        _serverError =
            result['message'] ?? 'This phone number is not registered.';
      });
      return false;
    }

    setState(() {
      _serverError = null;
    });
    return true;
  }

  String? validatePhone(String value) {
    value = value.trim();
    final phonePattern = RegExp(r'^1[0-9]{8,9}$'); // Malaysian format without 0
    if (value.isEmpty) return 'Please enter your phone number';
    if (!phonePattern.hasMatch(value)) return 'Invalid phone number format';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = phoneController.text.trim();

    setState(() => _loading = true);

    final registered = await isPhoneRegistered(phone);

    setState(() => _loading = false);

    if (!registered) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OTPVerificationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 30),
                SizedBox(
                  height: 140,
                  child: Image.asset('assets/images/OTP.png'),
                ),
                const SizedBox(height: 24),
                const Text(
                  "OTP Verification",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  "We will send you a one time password to\nyour phone number",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // 📱 Phone Number Field
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixText: '+60 ',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    errorText: _serverError, // Show server-side error here
                  ),
                  validator: (value) => validatePhone(value ?? ''),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.hunterGreen,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _loading
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text(
                              'Get OTP',
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
}
