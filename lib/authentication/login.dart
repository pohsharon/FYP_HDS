import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/nav.dart';
import 'package:fyp_hbs/authentication/forgot_password.dart';
import 'package:fyp_hbs/services/api/auth_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool _isLoading = false;

  String? phoneError;
  String? passwordError;
  String? globalError; // For credential / server errors

  String? _sanitizeError(String? err) {
    if (err == null) return null;
    final lower = err.toLowerCase();
    // Common noisy technical patterns we don't want to show to users.
    final technical = [
      'sqlstate',
      'could not translate',
      'could not resolve host',
      'connection:',
      'pg:',
      'psql',
      'nodename',
      'servname',
      'supabase',
      'socket',
    ];
    for (final t in technical) {
      if (lower.contains(t)) return 'No internet connection — please try again later.';
    }
    // Keep generic network messages as-is, but shorten long server traces.
    if (lower.contains('network error') || lower.contains('failed') || lower.contains('timeout')) {
      return 'Network error — please try again later.';
    }
    // Otherwise return original user-facing message
    return err;
  }

  void _validateFields() {
    setState(() {
      phoneError =
          phoneController.text.isEmpty ? "Please enter your phone number" : null;
      passwordError =
          passwordController.text.isEmpty ? "Please enter your password" : null;
      globalError = null; // reset previous error
    });
  }

  Future<void> _login() async {
    _validateFields();

    // Stop if there are validation errors
    if (phoneError != null || passwordError != null) return;

    setState(() {
      _isLoading = true;
      globalError = null;
    });

    // If there's no internet, show a friendly message instead of a raw
    // network/SQL error. This prevents exposing internal error details to
    // the user (see screenshot) and provides a clear action.
    try {
      final conn = await Connectivity().checkConnectivity();
      if (conn == ConnectivityResult.none) {
        setState(() {
          _isLoading = false;
          globalError = 'No internet connection — please try again later.';
        });
        return;
      }
    } catch (_) {
      // If connectivity check itself fails, continue and let the login
      // call surface errors. We still protect against the common offline case
      // above.
    }

    try {
      final response = await AuthService.login(
        phoneController.text.trim(),
        passwordController.text.trim(),
      );

      if (response.containsKey("token")) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const Nav()),
          (route) => false,
        );
      } else {
        setState(() {
          globalError = _sanitizeError(response["message"] ?? "Invalid credentials");
        });
      }
    } catch (e) {
      setState(() {
        globalError = _sanitizeError("Something went wrong. Please try again later.");
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  const CircleAvatar(
                    radius: 80,
                    backgroundColor: AppColors.hunterGreen,
                    child: CircleAvatar(
                      radius: 70,
                      backgroundImage: AssetImage('assets/images/logo.png'),
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),

                  const Text(
                    'Welcome Back',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // Global Error Banner
                  if (globalError != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              globalError!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Phone Number Field
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      filled: true,
                      fillColor: Colors.white,
                      errorText: phoneError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      filled: true,
                      fillColor: Colors.white,
                      errorText: passwordError,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.hunterGreen,
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Forgot your password?',
                        style: TextStyle(
                          color: AppColors.gray700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sign In Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.hunterGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
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