import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/widgets/persistent_appbar.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:fyp_hbs/authentication/reset_password.dart';
import 'package:fyp_hbs/authentication/login.dart';
import 'package:fyp_hbs/services/api/auth_service.dart';
import 'package:fyp_hbs/utils/connectivity_helper.dart';


class HarvestPage extends StatefulWidget {
  const HarvestPage({super.key});

  @override
  State<HarvestPage> createState() => _HarvestPageState();
}

class _HarvestPageState extends State<HarvestPage> {
  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 10,
                bottom: 0,
              ),
              leading: Icon(
                Icons.lock,
                color: AppColors.gray700,
              ),
              title: Text(
                'Change Password',
                style: TextStyle(color: AppColors.gray700),
              ),
              onTap: () async {
                final hasInternet = await ConnectivityHelper.hasInternetConnection();
                if (hasInternet) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ResetPasswordPage(fromSettings: true),
                    ),
                  );
                } else {
                  await Flushbar(
                    message: 'Changing password requires internet connection',
                    icon: const Icon(Icons.cloud_off, color: Colors.white),
                    backgroundColor: Colors.orange.shade700,
                    duration: const Duration(seconds: 2),
                    borderRadius: BorderRadius.circular(12),
                    margin: const EdgeInsets.all(12),
                    flushbarPosition: FlushbarPosition.TOP,
                  ).show(context);
                }
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 0,
                bottom: 20,
              ),
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );

                if (shouldLogout == true) {
                  try {
                    final ok = await AuthService.logout();

                    if (ok) {
                      await Flushbar(
                        message: 'Logged out',
                        icon: const Icon(Icons.check_circle, color: Colors.white),
                        backgroundColor: Colors.green.shade700,
                        duration: const Duration(seconds: 2),
                        borderRadius: BorderRadius.circular(12),
                        margin: const EdgeInsets.all(12),
                        flushbarPosition: FlushbarPosition.TOP,
                      ).show(context);
                    } else {
                      await Flushbar(
                        message: 'Logging out',
                        icon: const Icon(Icons.info, color: Colors.white),
                        backgroundColor: Colors.orange.shade700,
                        duration: const Duration(seconds: 2),
                        borderRadius: BorderRadius.circular(12),
                        margin: const EdgeInsets.all(12),
                        flushbarPosition: FlushbarPosition.TOP,
                      ).show(context);
                    }

                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                    );
                  } catch (e) {
                    await Flushbar(
                      message: 'Logout failed: $e',
                      icon: const Icon(Icons.error, color: Colors.white),
                      backgroundColor: Colors.red.shade700,
                      duration: const Duration(seconds: 3),
                      borderRadius: BorderRadius.circular(12),
                      margin: const EdgeInsets.all(12),
                      flushbarPosition: FlushbarPosition.TOP,
                    ).show(context);
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PersistentAppBar(
        title: 'Harvest',
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _openSettings,
        ),
      ),
      body: Center(
        child: Text(
          'Harvest List Placeholder',
          style: TextStyle(fontSize: 18, color: AppColors.gray700),
        ),
      ),
      backgroundColor: AppColors.background,
    );
  }
}