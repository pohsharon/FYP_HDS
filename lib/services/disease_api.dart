import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class DiseaseApi {
  static Future<void> createDisease({
    required String diseaseName,
    required String symptoms,
    required String remarks,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse("${Config.apiBaseUrl}/diseases"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "diseaseName": diseaseName,
          "symptoms": symptoms,
          "remarks": remarks,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data["message"] ?? "Failed to create disease");
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  static Future<void> updateDisease({
    required String diseaseName,
    required String symptoms,
    required String remarks,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.put(
        Uri.parse("${Config.apiBaseUrl}/diseases"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "diseaseName": diseaseName,
          "symptoms": symptoms,
          "remarks": remarks,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        final data = jsonDecode(response.body);
        throw Exception(data["message"] ?? "Failed to update disease");
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  static Future<void> deleteDisease(String id) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.delete(
        Uri.parse("${Config.apiBaseUrl}/diseases/$id"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to delete disease');
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  static Future<List<Map<String, dynamic>>> fetchDiseases() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse("${Config.apiBaseUrl}/diseases"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data["message"] ?? "Failed to fetch diseases");
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }
}
