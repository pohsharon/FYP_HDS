import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config.dart';
import '../app_initializer.dart';

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
    // Normalize phone: if it starts with 0, replace with 60; if already has 60, keep it
    if (phone.startsWith('0')) {
      phone = '6${phone.substring(1)}'; // 01234567 -> 601234567
    } else if (!phone.startsWith('60')) {
      phone = '60$phone'; // 1234567 -> 601234567
    }
    // else: already starts with 60, keep as is

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

  static Future<Map<String, dynamic>> verifyOTP(String phone, String otp) async {
    try {
      phone = phone.trim();
      // Normalize phone: if it starts with 0, replace with 60; if already has 60, keep it
      if (phone.startsWith('0')) {
        phone = '6${phone.substring(1)}'; // 01234567 -> 601234567
      } else if (!phone.startsWith('60')) {
        phone = '60$phone'; // 1234567 -> 601234567
      }
      // else: already starts with 60, keep as is

      final response = await http.post(
        Uri.parse("${Config.apiBaseUrl}/verify-otp"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "phone": phone,
          "otp": otp,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        return {
          "success": false,
          "message": data["message"] ?? "OTP verification failed"
        };
      }
    } catch (e) {
      print('Error verifying OTP: $e');
      return {
        "success": false,
        "message": "Network error. Please try again later."
      };
    }
  }

  static Future<Map<String, dynamic>> resetPassword(
    String phone,
    String newPassword,
    String newPasswordConfirmation,
  ) async {
    try {
      phone = phone.trim();
      // Normalize phone: if it starts with 0, replace with 60; if already has 60, keep it
      if (phone.startsWith('0')) {
        phone = '6${phone.substring(1)}'; // 01234567 -> 601234567
      } else if (!phone.startsWith('60')) {
        phone = '60$phone'; // 1234567 -> 601234567
      }
      // else: already starts with 60, keep as is

      final response = await http.post(
        Uri.parse("${Config.apiBaseUrl}/reset-password"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "phone": phone,
          "new_password": newPassword,
          "new_password_confirmation": newPasswordConfirmation,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": data["message"] ?? "Password reset successfully"
        };
      } else {
        return {
          "success": false,
          "message": data["message"] ?? "Password reset failed"
        };
      }
    } catch (e) {
      print('Error resetting password: $e');
      return {
        "success": false,
        "message": "Network error. Please try again later."
      };
    }
  }

  /// Attempt to logout on the server (if online) and always clear local auth state.
  ///
  /// Returns `true` when the server-side logout completed (or responded
  /// with an expected idempotent response). If a network error occurred the
  /// method still clears local state and returns `false` (server revocation
  /// pending). The caller should handle navigation after calling this.
  static Future<bool> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    bool serverOk = false;

    // attempt server-side logout, but don't fail the whole flow if it errors
    try {
      if (token != null) {
        final res = await http.post(
          Uri.parse("${Config.apiBaseUrl}/api/logout"),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        );
        // treat 200/204/401/403 as success (idempotent)
        if ([200, 204, 401, 403].contains(res.statusCode)) {
          serverOk = true;
        } else {
          // unexpected status
          serverOk = false;
        }
      }
    } catch (e) {
      // network issue or server error: mark pending logout for later retry
      await prefs.setBool('pending_server_logout', true);
      serverOk = false;
    }

    // Always clear local auth state (support older/newer key names)
    await prefs.remove('token');
    await prefs.remove('user');
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_json');

    return serverOk;
  }

  /// Cache all data after successful login
  static Future<void> cacheAfterLogin() async {
    await AppInitializer.cacheAllData();
    AppInitializer.enableConnectivitySync();
  }

  /// Get current logged-in user's phone number
  static Future<String?> getCurrentUserPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      if (userJson != null && userJson.isNotEmpty) {
        final userData = jsonDecode(userJson);
        return userData['phone']?.toString();
      }
    } catch (e) {
      print('Error retrieving current user phone: $e');
    }
    return null;
  }
}
