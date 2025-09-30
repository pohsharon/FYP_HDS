import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class TreeGrowthApi {
  static Future<Map<String, dynamic>> addGrowthLog({
    required int treeId,
    required String treeUuid,
    required double height,
    required double diameter,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse("${Config.apiBaseUrl}/tree-growth-logs"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "tree_id": treeId,
          "tree_uuid": treeUuid,
          "height": height,
          "diameter": diameter,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data["message"] ?? "Failed to create growth log");
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  static Future<List<Map<String, dynamic>>> fetchGrowthLogs(
    String treeUuid,
  ) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse("${Config.apiBaseUrl}/$treeUuid/growth-logs"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception(data["message"] ?? "Failed to fetch growth logs");
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  static Future<List<Map<String, dynamic>>> fetchGrowthLogsByUuid(
    String treeUuid,
  ) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse("${Config.apiBaseUrl}/tree-growth-logs/$treeUuid"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data is Map<String, dynamic> && data.containsKey("data")) {
          return List<Map<String, dynamic>>.from(data["data"]);
        } else {
          throw Exception("Unexpected API response format");
        }
      } else {
        throw Exception(data["message"] ?? "Failed to fetch growth logs");
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }
}
