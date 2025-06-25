import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class TreeApi {
  static Future<Map<String, dynamic>> createTree({
    required String speciesId,
    required String plantedAt,
    required double height,
    required double diameter,
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
          "height": height,
          "diameter": diameter,
          "flowering_period": floweringPeriod,
          "thumbnail": imageBase64,
        }),
      );

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

  static Future<Map<String, dynamic>> getTreeById(String id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final url = "${Config.apiBaseUrl}/trees/$id";
    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Accept": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to fetch tree details");
    }
  }

  static Future<Map<String, dynamic>> getTreeByUuid(String uuid) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final url = "${Config.apiBaseUrl}/trees/uuid/$uuid";
    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Accept": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to fetch tree details");
    }
  }

  static Future<void> updateTree({
    required String id,
    required String speciesId,
    required String plantedAt,
    required double height,
    required double diameter,
    required String floweringPeriod,
    String? imageBase64,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.put(
        Uri.parse("${Config.apiBaseUrl}/trees/$id"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "species_id": speciesId,
          "planted_at": plantedAt,
          "height": height,
          "diameter": diameter,
          "flowering_period": floweringPeriod,
          if (imageBase64 != null) "thumbnail": imageBase64,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else {
        throw Exception(data["message"] ?? "Failed to update tree");
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  static Future<void> deleteTree(String id) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  final response = await http.delete(
    Uri.parse("${Config.apiBaseUrl}/trees/$id"),
    headers: {
      "Accept": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    },
  );

  if (response.statusCode == 200) {
    return;
  }

  if (response.body.trim().isNotEmpty) {
    try {
      final data = jsonDecode(response.body);
      throw Exception(data["message"] ?? "Failed to delete tree");
    } catch (e) {
      throw Exception("Unexpected error: ${response.body}");
    }
  }

  throw Exception("Failed to delete tree (No response body)");
}

}
