import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class BuyerApi {
  /// Create a new buyer
  static Future<Map<String, dynamic>> createBuyer({
    required String companyName,
    required String contactName,
    String? contactNumber,
    String? email,
    String? address,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse("${Config.apiBaseUrl}/buyers"),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'company_name': companyName,
          'contact_name': contactName,
          'contact_number': contactNumber,
          'email': email,
          'address': address,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to create buyer');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  /// Fetch all buyers
  static Future<List<Map<String, dynamic>>> fetchBuyers() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse("${Config.apiBaseUrl}/buyers"),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch buyers');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  /// Get buyer details by ID
  static Future<Map<String, dynamic>> getBuyerId(String buyerId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token'); 
      final response = await http.get(
        Uri.parse("${Config.apiBaseUrl}/buyers/$buyerId"),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data['data'];
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch buyer details');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<void> updateBuyer({
    required String buyerId,
    required String companyName,
    required String contactName,
    String? contactNumber,
    String? email,
    String? address,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.put(
        Uri.parse("${Config.apiBaseUrl}/buyers/$buyerId"),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'company_name': companyName,
          'contact_name': contactName,
          'contact_number': contactNumber,
          'email': email,
          'address': address,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(data['message'] ?? 'Failed to update buyer');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }
}
