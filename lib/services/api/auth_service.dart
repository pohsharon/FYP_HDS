import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(
    String phoneNumber,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("${Config.apiBaseUrl}/login"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({"phone": phoneNumber, "password": password}),
      );

      final data = jsonDecode(response.body);

      // ✅ Successful login
      if (response.statusCode == 200 && data.containsKey("token")) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", data["token"]);
        await prefs.setString("user", jsonEncode(data["user"]));
        return data;
      }

      // ❌ Invalid credentials or other server-side error
      return {"message": data["message"] ?? "Invalid credentials"};
    } catch (e) {
      // 🌐 Network or unexpected error
      return {"message": "Network error. Please try again later."};
    }
  }

  static Future<Map<String, dynamic>> checkPhone(String phone) async {
  try {
    phone = phone.trim();
    if (!phone.startsWith('0')) phone = '0$phone';

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final uri = Uri.parse("${Config.apiBaseUrl}/check-phone/$phone");
    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to check phone: ${response.statusCode}');
    }
  } catch (e) {
    print('Error checking phone: $e');
    return {'exists': false, 'message': 'Network error'};
  }
}
}
