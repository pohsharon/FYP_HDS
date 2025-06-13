import 'package:flutter/material.dart';
import 'package:fyp_hbs/authentication/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Geolocator.checkPermission(); 
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Hosba Durian System",
      home: LoginPage()
    );
  }
}
