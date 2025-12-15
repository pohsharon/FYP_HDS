import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/app_initializer.dart';

/// A small reusable AppBar widget used across the app.
/// Keeps a consistent look and exposes a sync action by default.
class PersistentAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? extraActions;

  const PersistentAppBar({super.key, required this.title, this.leading, this.extraActions});

  @override
  Widget build(BuildContext context) {
    // Sync button always present at the right-most side
    final syncButton = IconButton(
      icon: const Icon(Icons.sync),
      tooltip: 'Sync',
      onPressed: () async {
        // Use the root overlay's context for showing Flushbar so the
        // context remains valid even if this widget gets disposed while
        // awaiting (for example AppInitializer.initializeApp()).
        final overlayContext = Navigator.of(context, rootNavigator: true).overlay?.context ?? context;

        // Quick offline check — if there's no network, show a clear error
        // message and don't attempt the full sync flow.
        try {
          final conn = await Connectivity().checkConnectivity();
          if (conn == ConnectivityResult.none) {
            // Show a concise modal telling the user we can't sync without
            // internet. A dialog is a clear, professional affordance and
            // avoids overlay/context lifecycle issues.
            await showDialog<void>(
              context: overlayContext,
              barrierDismissible: true,
              builder: (ctx) => AlertDialog(
                title: Row(
                  children: const [
                    Icon(Icons.wifi_off, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(child: Text('No internet')),
                  ],
                ),
                content: const Text('No internet connection — please try again later.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            return;
          }
        } catch (e) {
          // If connectivity check fails for some reason, continue and let
          // AppInitializer surface more detailed errors.
        }

        try {
          await Flushbar(
            message: 'Syncing...',
            icon: const Icon(Icons.sync, color: Colors.white),
            backgroundColor: AppColors.pakistanGreen,
            duration: const Duration(seconds: 2),
            borderRadius: BorderRadius.circular(8),
            margin: const EdgeInsets.all(12),
          ).show(overlayContext);

          await AppInitializer.initializeApp();

          await Flushbar(
            message: 'Sync complete',
            icon: const Icon(Icons.check_circle, color: Colors.white),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
            borderRadius: BorderRadius.circular(8),
            margin: const EdgeInsets.all(12),
          ).show(overlayContext);
        } catch (e) {
          await Flushbar(
            message: 'Sync failed: $e',
            icon: const Icon(Icons.error, color: Colors.white),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
            borderRadius: BorderRadius.circular(8),
            margin: const EdgeInsets.all(12),
          ).show(overlayContext);
        }
      },
    );

    return AppBar(
      title: Text(title),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      leading: leading,
      actions: [
        ...?extraActions,
        syncButton,
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
