import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'package:http_parser/http_parser.dart';

class TreeApi {
  static Future<Map<String, dynamic>> createTree({
    required String speciesId,
    required String plantedAt,
    required double height,
    required double diameter,
    required String floweringPeriod,
    File? imageFile,
  }) async {
    final uri = Uri.parse("${Config.apiBaseUrl}/trees");
    var request = http.MultipartRequest('POST', uri);

    // Add fields
    request.fields['species_id'] = speciesId;
    request.fields['planted_at'] = plantedAt;
    request.fields['height'] = height.toString();
    request.fields['diameter'] = diameter.toString();
    request.fields['flowering_period'] = floweringPeriod;

    // Add image if present
    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('thumbnail', imageFile.path),
      );
    }

    // Add headers (Authorization, Accept)
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    request.headers['Accept'] = 'application/json';
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    // Try to decode JSON, else throw readable error
    try {
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to create tree');
      }
    } catch (e) {
      throw Exception('Failed to create tree: ${response.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchSpecies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse("${Config.apiBaseUrl}/species"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Normalize to a list whether the API returns { data: [...] } or directly [...]
        List<dynamic> items;
        if (decoded is Map && decoded.containsKey('data')) {
          items = (decoded['data'] as List<dynamic>);
        } else if (decoded is List) {
          items = decoded;
        } else {
          throw Exception('Unexpected response format for species');
        }

        // Convert each item to a Map<String, dynamic>
        return items.map<Map<String, dynamic>>((item) {
          if (item is Map) return Map<String, dynamic>.from(item);
          if (item is String) return {'id': null, 'name': item};
          return {'id': null, 'name': item?.toString() ?? ''};
        }).toList();
      } else {
        final message =
            (decoded is Map)
                ? decoded["message"] ?? "Failed to fetch species"
                : "Failed to fetch species";
        throw Exception(message);
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  static Future<Map<String, dynamic>> fetchTrees({int page = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse("${Config.apiBaseUrl}/trees?page=$page"),
      headers: {
        "Accept": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      // ✅ return full decoded object (casted properly)
      return decoded;
    } else {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(decoded['message'] ?? 'Failed to fetch trees');
    }
  }

  static Future<Map<String, dynamic>> fetchAllTrees() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse("${Config.apiBaseUrl}/trees?page=all"),
      headers: {
        "Accept": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded;
    } else {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(decoded['message'] ?? 'Failed to fetch trees');
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
    File? imageFile,
  }) async {
    try {
      final uri = Uri.parse("${Config.apiBaseUrl}/trees/$id");
      var request = http.MultipartRequest('POST', uri);

      // Method override for PUT if your Laravel route uses PUT/PATCH
      request.fields['_method'] = 'PUT';

      // Add fields
      request.fields['species_id'] = speciesId;
      request.fields['planted_at'] = plantedAt;
      request.fields['height'] = height.toString();
      request.fields['diameter'] = diameter.toString();
      request.fields['flowering_period'] = floweringPeriod;

      // Add image if present
      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('thumbnail', imageFile.path),
        );
      }

      // Add headers
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Decode JSON
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 204) {
        print("Tree updated successfully");
        return;
      } else {
        throw Exception(data["message"] ?? "Failed to update tree");
      }
    } catch (e) {
      throw Exception("Error updating tree: ${e.toString()}");
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

  static Future<void> addTreeLocation({
    required String treeUuid,
    required double latitude,
    required double longitude,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.put(
      Uri.parse("${Config.apiBaseUrl}/trees/location/$treeUuid"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode({"latitude": latitude, "longitude": longitude}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data["message"] ?? "Failed to add tree location");
    }
  }

  static Future<List<Map<String, dynamic>>> fetchEvents() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse("${Config.apiBaseUrl}/harvest-events"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        // if it's wrapped
        if (decoded is Map && decoded.containsKey("data")) {
          return List<Map<String, dynamic>>.from(decoded["data"]);
        }

        // if it's directly a list
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }

        throw Exception("Unexpected response format: $decoded");
      } else {
        throw Exception("Failed to load events");
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  static Future<List<Map<String, dynamic>>> getHarvestsByTreeId(
    String treeUuid,
  ) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await http.get(
        Uri.parse("${Config.apiBaseUrl}/trees/$treeUuid/harvest-events"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception("Failed to fetch harvests");
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }
}
