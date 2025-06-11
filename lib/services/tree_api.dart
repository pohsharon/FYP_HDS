import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class TreeApi {
  static Future<Map<String, dynamic>> createTree({
    required String speciesId,
    required String plantedAt,
    required double height,
    required double width,
    required String floweringPeriod,
    required String imageBase64,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse("${Config.apiBaseUrl}/trees"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "species_id": speciesId,
          "planted_at": plantedAt,
          "initial_height": height,
          "initial_width": width,
          "flowering_period": floweringPeriod,
          "thumbnail_base64": imageBase64,
        }),
      );
      print("Response Status: ${response.statusCode}");
      print("Response Body: ${response.body}");
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data["message"] ?? "Failed to create tree");
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  static Future<List<Map<String, dynamic>>> fetchSpecies() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse("${Config.apiBaseUrl}/species"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception(data["message"] ?? "Failed to fetch species");
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  static Future<List<Map<String, dynamic>>> fetchTrees() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse("${Config.apiBaseUrl}/trees"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception(data["message"] ?? "Failed to fetch trees");
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }
}