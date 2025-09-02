import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class FruitApi {
  static Future<Map<String, dynamic>> createFruit({
    required String tree_uuid,
    required String harvest_uuid,
    required double weight,
    required String grade,
    required String harvested_at,
    required bool is_spoiled,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse("${Config.apiBaseUrl}/fruit"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "tree_uuid": tree_uuid,
          "harvest_uuid": harvest_uuid,
          "weight": weight,
          "grade": grade,
          "harvested_at": harvested_at,
          "is_spoiled": is_spoiled,
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

  static Future<List<Map<String, dynamic>>> fetchFruits() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse("${Config.apiBaseUrl}/fruit"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data is Map && data["data"] is List) {
          return (data["data"] as List)
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList();
        }

        if (data is List) {
          return data
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList();
        }

        throw Exception("Unexpected response format: $data");
      } else {
        throw Exception(data["message"] ?? "Failed to fetch fruits");
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  // static Future<void> updateTree({
  //   required String id,
  //   required String speciesId,
  //   required String plantedAt,
  //   required double height,
  //   required double diameter,
  //   required String floweringPeriod,
  //   String? imageBase64,
  // }) async {
  //   try {
  //     SharedPreferences prefs = await SharedPreferences.getInstance();
  //     final token = prefs.getString('token');

  //     final response = await http.put(
  //       Uri.parse("${Config.apiBaseUrl}/trees/$id"),
  //       headers: {
  //         "Content-Type": "application/json",
  //         "Accept": "application/json",
  //         if (token != null) "Authorization": "Bearer $token",
  //       },
  //       body: jsonEncode({
  //         "species_id": speciesId,
  //         "planted_at": plantedAt,
  //         "height": height,
  //         "diameter": diameter,
  //         "flowering_period": floweringPeriod,
  //         if (imageBase64 != null) "thumbnail": imageBase64,
  //       }),
  //     );

  //     final data = jsonDecode(response.body);

  //     if (response.statusCode == 200 || response.statusCode == 204) {
  //       return;
  //     } else {
  //       throw Exception(data["message"] ?? "Failed to update tree");
  //     }
  //   } catch (e) {
  //     throw Exception("Error: ${e.toString()}");
  //   }
  // }

  // static Future<void> deleteTree(String id) async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   final token = prefs.getString('token');

  //   final response = await http.delete(
  //     Uri.parse("${Config.apiBaseUrl}/trees/$id"),
  //     headers: {
  //       "Accept": "application/json",
  //       if (token != null) "Authorization": "Bearer $token",
  //     },
  //   );

  //   if (response.statusCode == 200) {
  //     return;
  //   }

  //   if (response.body.trim().isNotEmpty) {
  //     try {
  //       final data = jsonDecode(response.body);
  //       throw Exception(data["message"] ?? "Failed to delete tree");
  //     } catch (e) {
  //       throw Exception("Unexpected error: ${response.body}");
  //     }
  //   }

  //   throw Exception("Failed to delete tree (No response body)");
  // }
}
