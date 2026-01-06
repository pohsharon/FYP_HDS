import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fyp_hbs/utils/connectivity_helper.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/app_initializer.dart';

/// A small reusable AppBar widget used across the app.
/// Keeps a consistent look and exposes a sync action by default.
class PersistentAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? extraActions;

  const PersistentAppBar({
    super.key,
    required this.title,
    this.leading,
    this.extraActions,
  });

  Future<void> _handleSync(BuildContext context) async {
    // Use the root overlay's context for showing Flushbar so the
    // context remains valid even if this widget gets disposed while
    // awaiting (for example AppInitializer.initializeApp()).
    final overlayContext =
        Navigator.of(context, rootNavigator: true).overlay?.context ?? context;

    // Quick offline check — if there's no network or no internet, surface
    // a clear inline error and skip syncing.
    final hasInternet = await ConnectivityHelper.hasInternetConnection();
    if (!hasInternet) {
      await Flushbar(
        message: 'No internet connection — sync unavailable.',
        icon: const Icon(Icons.wifi_off, color: Colors.white),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
        borderRadius: BorderRadius.circular(8),
        margin: const EdgeInsets.all(12),
      ).show(overlayContext);
      return;
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
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      leading: leading,
      actions: [
        _ConnectionBadge(onTap: () => _handleSync(context)),
        ...?extraActions,
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({this.onTap});

  final VoidCallback? onTap;

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Stream<bool> _connectivityStream() {
    // Combine connectivity changes with a quick reachability probe for real internet access.
    return Stream.multi((controller) {
      bool? last;

      Future<void> emitStatus() async {
        try {
          final conn = await Connectivity().checkConnectivity();
          final hasNetwork = conn != ConnectivityResult.none;
          final hasInternet = hasNetwork && await _hasInternet();
          final online = hasNetwork && hasInternet;
          if (last == null || online != last) {
            last = online;
            controller.add(online);
          }
        } catch (_) {
          if (last != false) {
            last = false;
            controller.add(false);
          }
        }
      }

      // Initial status
      emitStatus();

      // Realtime changes
      final sub = Connectivity().onConnectivityChanged.listen((_) => emitStatus());

      // Short periodic poll to catch cases where connectivity events don't fire
      final timer = Timer.periodic(const Duration(seconds: 4), (_) => emitStatus());

      controller.onCancel = () {
        sub.cancel();
        timer.cancel();
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ValueListenableBuilder<bool>(
        valueListenable: AppInitializer.syncInProgress,
        builder: (context, syncing, _) {
          return StreamBuilder<bool>(
            stream: _connectivityStream(),
            builder: (context, snapshot) {
              final online = snapshot.data ?? true;
              final bg = online ? Colors.green.shade100 : Colors.red.shade100;
              final fg = online ? Colors.green.shade700 : Colors.red.shade700;
              final icon = syncing
                  ? null
                  : online
                      ? Icons.wifi
                      : Icons.wifi_off;
              final label = syncing
                  ? 'Syncing...'
                  : online
                      ? 'Online'
                      : 'Offline';

              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: syncing ? null : onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: fg.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (syncing)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(fg),
                          ),
                        )
                      else
                        Icon(icon, size: 16, color: fg),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
