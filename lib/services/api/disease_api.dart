import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config.dart';

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
    required String id,
    required String diseaseName,
    required String symptoms,
    required String remarks,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.put(
        Uri.parse("${Config.apiBaseUrl}/diseases/$id"),
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

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // Ensure we correctly extract the "data" field
      if (decoded is Map && decoded.containsKey('data')) {
        final List<dynamic> dataList = decoded['data'];

        return dataList
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      } else {
        throw Exception('Unexpected response format: missing "data" key');
      }
    } else {
      final message = (decoded is Map)
          ? decoded["message"] ?? "Failed to fetch diseases"
          : "Failed to fetch diseases";
      throw Exception(message);
    }
  } catch (e) {
    throw Exception("Error: ${e.toString()}");
  }
}

  static Future<List<Map<String, dynamic>>> fetchTreesByDisease(String diseaseId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse("${Config.apiBaseUrl}/diseases/$diseaseId/trees"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Extract the "data" field if present, otherwise treat as direct list
        if (decoded is Map && decoded.containsKey('data')) {
          final List<dynamic> dataList = decoded['data'];
          return dataList
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        } else if (decoded is List) {
          return decoded
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        } else {
          throw Exception('Unexpected response format');
        }
      } else {
        final message = (decoded is Map)
            ? decoded["message"] ?? "Failed to fetch trees for disease"
            : "Failed to fetch trees for disease";
        throw Exception(message);
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }
}
