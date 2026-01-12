import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config.dart';

class AgrochemicalApi {
  static Future<List<Map<String, dynamic>>> fetchAgrochemicals({
    required String treeUuid,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse("${Config.apiBaseUrl}/trees/$treeUuid/agrochemicals"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(decoded['data']);
    } else {
      throw Exception("Failed to fetch agrochemicalsss");
    }
  }

  static Future<Map<String, dynamic>> createAgrochemicalRecord({
    required String tree_uuid,
    required String agrochemical_uuid,
    required String applied_at,
    required String description,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse("${Config.apiBaseUrl}/agrochemicals"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "tree_uuid": tree_uuid,
          "agrochemical_uuid": agrochemical_uuid,
          "applied_at": applied_at,
          "description": description,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data["message"] ?? "Failed to create agrochemical");
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  static Future<void> updateAgrochemicalRecord({
    required String record_uuid,
    required String agrochemical_uuid,
    required String tree_uuid,
    required String applied_at,
    required String description,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.put(
        Uri.parse("${Config.apiBaseUrl}/agrochemicals/$record_uuid"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "agrochemical_uuid": agrochemical_uuid,
          "tree_uuid": tree_uuid,
          "applied_at": applied_at,
          "description": description,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      } else {
        throw Exception(
          data["message"] ?? "Failed to update agrochemical record",
        );
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  static Future<List<Map<String, dynamic>>> getAgrochemical() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse("${Config.apiBaseUrl}/agrochemicals"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(decoded['data']);
    } else {
      throw Exception("Failed to fetch agrochemicals");
    }
  }

  static Future<void> deleteAgrochemicalRecord(String recordUuid) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.delete(
        Uri.parse("${Config.apiBaseUrl}/agrochemicals/$recordUuid"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to delete agrochemical record');
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  // Fetch trees associated with a specific agrochemical
  static Future<List<Map<String, dynamic>>> fetchTreesByAgrochemical(
    String agrochemicalUuid,
  ) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse("${Config.apiBaseUrl}/agrochemicals/$agrochemicalUuid/trees"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (decoded is Map && decoded.containsKey('data')) {
          final List<dynamic> dataList = decoded['data'];
          return dataList.map((e) => Map<String, dynamic>.from(e)).toList();
        }
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
        throw Exception('Unexpected response format');
      }

      final message = (decoded is Map)
          ? decoded['message'] ?? 'Failed to fetch trees for agrochemical'
          : 'Failed to fetch trees for agrochemical';
      throw Exception(message);
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  // Fetch all agrochemical records (global endpoint) and return the list of rows
  static Future<List<Map<String, dynamic>>> fetchAllAgroRecords() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse("${Config.apiBaseUrl}/agrochemical-records"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(decoded['data']);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to fetch agrochemical records');
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  // Fetch agrochemicals with available stock (quantity > 0)
  static Future<List<Map<String, dynamic>>> getAvailableAgrochemicals() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse("${Config.apiBaseUrl}/agrochemicals/available/stock"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final agrochemicals = List<Map<String, dynamic>>.from(decoded['data']);
        
        // Cache to SharedPreferences for offline use
        try {
          await prefs.setString(
            'available_agrochemicals_cache',
            jsonEncode(agrochemicals),
          );
          print('✅ Cached ${agrochemicals.length} agrochemicals');
        } catch (e) {
          print('⚠️ Failed to cache agrochemicals: $e');
        }
        
        return agrochemicals;
      } else {
        throw Exception("Failed to fetch available agrochemicals");
      }
    } catch (e) {
      // Try to load from cache on error
      try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('available_agrochemicals_cache');
        if (cached != null && cached.isNotEmpty) {
          print('📦 Loaded ${jsonDecode(cached).length} agrochemicals from cache');
          return List<Map<String, dynamic>>.from(jsonDecode(cached));
        }
      } catch (cacheErr) {
        print('⚠️ Failed to load from cache: $cacheErr');
      }
      throw Exception("Error: ${e.toString()}");
    }
  }

  // Create agrochemical stock movement (out)
  static Future<Map<String, dynamic>> createStockMovement({
    required String agrochemicalUuid,
    required int quantity,
    required String date,
    String? description,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse("${Config.apiBaseUrl}/agrochemical-stock-movements"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "agrochemical_uuid": agrochemicalUuid,
          "movement_type": "out",
          "quantity": quantity,
          "date": date,
          if (description != null && description.isNotEmpty) "description": description,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data["message"] ?? "Failed to create stock movement");
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }
}
