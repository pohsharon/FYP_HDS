import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(String phoneNumber, String password) async {
    try {
      final response = await http.post(
        Uri.parse("${Config.apiBaseUrl}/login"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "phone": phoneNumber, 
          "password": password
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        if (data.containsKey("token")) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString("token", data["token"]);
          await prefs.setString("user", jsonEncode(data["user"])); // Store user data
        }
        return data;
      } else {
        throw Exception(data["message"] ?? "Login failed");
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }
}