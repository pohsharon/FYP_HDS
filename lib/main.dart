import 'package:flutter/material.dart';
import 'package:fyp_hbs/authentication/login.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'services/app_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Geolocator.checkPermission();

  // (We use a simple file-backed tile cache implemented in the app.)

  // Initialize connectivity listener only - caching happens after login
  AppInitializer.initConnectivityListener();
  // Ensure connectivity-driven syncs are enabled even for already logged-in users
  AppInitializer.enableConnectivitySync();
  // final localDB = LocalDB.instance;
  // await localDB.resetTreesTable();


  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Hosba Durian System",
      navigatorKey: AppInitializer.navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.pakistanGreen,
          primary: AppColors.pakistanGreen,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.pakistanGreen,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.pakistanGreen,
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.pakistanGreen,
            side: BorderSide(color: AppColors.pakistanGreen),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.all(AppColors.pakistanGreen),
          trackColor: WidgetStateProperty.all(
            AppColors.pakistanGreen.withOpacity(0.5),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
        ),
      ),
      home: const GlobalKeyboardDismissal(
        child: LoginPage(),
      ),
    );
  }
}

/// Custom widget that wraps the entire app to dismiss keyboard on tap anywhere
class GlobalKeyboardDismissal extends StatelessWidget {
  final Widget child;

  const GlobalKeyboardDismissal({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: child,
    );
  }
}
