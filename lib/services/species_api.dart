import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'package:fyp_hbs/home/species/model/species.dart';

class SpeciesApi {
  /// Create species
  static Future<Map<String, dynamic>> createSpecies({
    required String name,
    required String code,
    String? description,
    required bool isActive,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse("${Config.apiBaseUrl}/species"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "name": name,
          "code": code,
          "description": description,
          "is_active": isActive,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data["message"] ?? "Failed to create species");
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  /// Fetch species list
  static Future<List<Species>> fetchSpecies() async {
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

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final List<dynamic> data = body['data'];
        return data.map((json) => Species.fromJson(json)).toList();
      } else {
        throw Exception(body['message'] ?? 'Failed to load species');
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }
}