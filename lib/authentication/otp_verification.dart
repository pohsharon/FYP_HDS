import 'package:flutter/material.dart';
import 'package:fyp_hbs/authentication/reset_password.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:fyp_hbs/services/api/auth_service.dart';

class OTPVerificationPage extends StatelessWidget {
  final String email;
  final String phone;

  const OTPVerificationPage({
    super.key,
    required this.email,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController otpController = TextEditingController();

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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                const SizedBox(height: 20),
                // OTP Illustration
                SizedBox(
                  height: 120,
                  child: Image.asset('assets/images/OTP.png'),
                ),
                const SizedBox(height: 20),
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
                Text(
                  "You will receive a one time password at $email",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                // OTP Field (6 boxes)
                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  animationType: AnimationType.fade,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(8),
                    fieldHeight: 50,
                    fieldWidth: 45,
                    activeFillColor: Colors.white,
                    selectedFillColor: Colors.white,
                    inactiveFillColor: Colors.white,
                    activeColor: AppColors.hunterGreen,
                    selectedColor: AppColors.hunterGreen,
                    inactiveColor: AppColors.gray400,
                    borderWidth: 1.5,
                  ),
                  backgroundColor: Colors.transparent,
                  enableActiveFill: true,
                  onChanged: (value) {},
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Validate OTP
                      if (otpController.text.isEmpty ||
                          otpController.text.length < 6) {
                        final overlayContext =
                            Navigator.of(context, rootNavigator: true).overlay!.context;
                        Flushbar(
                          message: 'Please enter OTP',
                          icon: const Icon(Icons.error, color: Colors.white),
                          backgroundColor: Colors.red.shade700,
                          duration: const Duration(seconds: 3),
                          borderRadius: BorderRadius.circular(8),
                          margin: const EdgeInsets.only(top: 50, left: 12, right: 12),
                          flushbarPosition: FlushbarPosition.TOP,
                        ).show(overlayContext);
                        return;
                      }

                      // Show loading
                      final overlayContext =
                          Navigator.of(context, rootNavigator: true).overlay!.context;
                      Flushbar(
                        message: 'Verifying OTP...',
                        icon: const Icon(Icons.sync, color: Colors.white),
                        backgroundColor: AppColors.hunterGreen,
                        duration: const Duration(seconds: 2),
                        borderRadius: BorderRadius.circular(8),
                        margin: const EdgeInsets.only(top: 50, left: 12, right: 12),
                        flushbarPosition: FlushbarPosition.TOP,
                      ).show(overlayContext);

                      // Verify OTP
                      final result = await AuthService.verifyOTP(
                        phone,
                        otpController.text,
                      );

                      if (result['success'] == true) {
                        // OTP verified successfully
                        final overlayContext =
                            Navigator.of(context, rootNavigator: true).overlay!.context;
                        Flushbar(
                          message: 'OTP verified successfully',
                          icon: const Icon(Icons.check_circle, color: Colors.white),
                          backgroundColor: Colors.green.shade700,
                          duration: const Duration(seconds: 2),
                          borderRadius: BorderRadius.circular(8),
                          margin: const EdgeInsets.only(top: 50, left: 12, right: 12),
                          flushbarPosition: FlushbarPosition.TOP,
                        ).show(overlayContext);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ResetPasswordPage(phone: phone),
                          ),
                        );
                      } else {
                        // Show error
                        final overlayContext =
                            Navigator.of(context, rootNavigator: true).overlay!.context;
                        Flushbar(
                          message: result['message'] ?? 'OTP verification failed',
                          icon: const Icon(Icons.error, color: Colors.white),
                          backgroundColor: Colors.red.shade700,
                          duration: const Duration(seconds: 3),
                          borderRadius: BorderRadius.circular(8),
                          margin: const EdgeInsets.only(top: 50, left: 12, right: 12),
                          flushbarPosition: FlushbarPosition.TOP,
                        ).show(overlayContext);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.hunterGreen,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Verify',
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
      ),
    );
  }
}
