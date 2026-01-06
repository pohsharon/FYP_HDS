import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config.dart';
import '../local database/disease_db.dart';
import 'package:uuid/uuid.dart';
import '../../utils/connectivity_helper.dart';

class DiseaseApi {
  static Future<void> createDisease({
    required String diseaseName,
    required String symptoms,
    required String remarks,
  }) async {
    final online = await ConnectivityHelper.hasInternetConnection();
    
    if (!online) {
      // Offline: Save to local DB with synced=0
      final uuid = const Uuid().v4();
      await DiseaseDB().insertDisease({
        'uuid': uuid,
        'disease_name': diseaseName,
        'symptoms': symptoms,
        'remarks': remarks,
        'synced': 0,
        'pending_update': 0,
        'pending_delete': 0,
      });
      print('📴 Disease saved offline: $uuid');
      return;
    }
    
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
        // Cache the created disease
        try {
          final diseaseData = data['data'] ?? data;
          await DiseaseDB().insertDisease({
            'id': diseaseData['id'],
            'uuid': diseaseData['uuid']?.toString() ?? const Uuid().v4(),
            'disease_name': diseaseName,
            'symptoms': symptoms,
            'remarks': remarks,
            'synced': 1,
            'pending_update': 0,
            'pending_delete': 0,
          });
        } catch (e) {
          print('⚠️ Failed to cache created disease: $e');
        }
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
    final online = await ConnectivityHelper.hasInternetConnection();
    
    if (!online) {
      // Offline: Update local DB and mark as pending update
      await DiseaseDB().updateDisease(id, {
        'disease_name': diseaseName,
        'symptoms': symptoms,
        'remarks': remarks,
        'pending_update': 1,
      });
      print('📴 Disease update saved offline: $id');
      return;
    }
    
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

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // Update local cache
        try {
          await DiseaseDB().updateDisease(id, {
            'disease_name': diseaseName,
            'symptoms': symptoms,
            'remarks': remarks,
            'synced': 1,
            'pending_update': 0,
          });
        } catch (e) {
          print('⚠️ Failed to update cached disease: $e');
        }
        return data;
      } else {
        throw Exception(data["message"] ?? "Failed to update disease");
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  static Future<void> deleteDisease(String id) async {
    final online = await ConnectivityHelper.hasInternetConnection();
    
    if (!online) {
      // Offline: Mark as pending delete (keep row for sync)
      await DiseaseDB().markAsPendingDelete(id);
      print('📴 Disease marked for deletion offline: $id');
      return;
    }
    
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
      
      // Delete from local cache
      try {
        await DiseaseDB().deleteDisease(id);
      } catch (e) {
        print('⚠️ Failed to delete cached disease: $e');
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

        final diseases = dataList
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        
        // Cache diseases for offline use
        try {
          await DiseaseDB().saveDiseaseList(diseases);
        } catch (e) {
          print('⚠️ Failed to cache diseases: $e');
        }
        
        return diseases;
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
    // Try loading from local cache as fallback
    try {
      final cached = await DiseaseDB().getAllDiseases();
      if (cached.isNotEmpty) {
        print('📦 Loaded ${cached.length} diseases from offline cache');
        return cached.map((row) {
          return {
            'id': row['id'],
            'diseaseName': row['disease_name'] ?? row['diseaseName'] ?? '',
            'symptoms': row['symptoms'] ?? '',
            'remarks': row['remarks'] ?? '',
          };
        }).toList();
      }
    } catch (cacheErr) {
      print('⚠️ Failed to load from disease cache: $cacheErr');
    }
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
