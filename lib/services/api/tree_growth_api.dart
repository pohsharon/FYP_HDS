import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config.dart';
import '../../utils/connectivity_helper.dart';
import '../local database/growth_db.dart';
import '../../models/tree_growth_model.dart';

class TreeGrowthApi {
  static Future<Map<String, dynamic>> addGrowthLog({
    // required int treeId,
    required String treeUuid,
    required double height,
    required double diameter,
  }) async {
    final isOnline = await ConnectivityHelper.hasInternetConnection();
    
    if (!isOnline) {
      // Save offline with pending sync flag
      final localUuid = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final growth = TreeGrowthModel(
        uuid: localUuid,
        treeUuid: treeUuid,
        height: height,
        diameter: diameter,
        createdAt: DateTime.now().toIso8601String(),
        synced: 0,
      );
      await GrowthDB().insertGrowth(growth);
      throw Exception("Saved offline, will sync when online");
    }
    
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
          // "tree_id": treeId,
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
    final isOnline = await ConnectivityHelper.hasInternetConnection();
    
    if (!isOnline) {
      // Return from local cache when offline
      try {
        final local = await GrowthDB().fetchAllGrowths(treeUuid: treeUuid);
        return local.map((g) => g.toMap()).toList();
      } catch (e) {
        print('⚠️ Failed to load local growth logs: $e');
        return [];
      }
    }
    
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
          final growthList = List<Map<String, dynamic>>.from(data["data"]);
          
          // Cache the results locally
          try {
            final growthModels = growthList.map((m) => TreeGrowthModel.fromMap(m)).toList();
            await GrowthDB().cacheRemoteGrowths(growthModels);
          } catch (e) {
            print('⚠️ Failed to cache growth logs: $e');
          }
          
          return growthList;
        } else {
          return <Map<String, dynamic>>[];
        }
      } else {
        return <Map<String, dynamic>>[];
      }
    } catch (e) {
      // Network error - try to return from local cache
      print('⚠️ Network error, returning local cache: $e');
      try {
        final local = await GrowthDB().fetchAllGrowths(treeUuid: treeUuid);
        return local.map((g) => g.toMap()).toList();
      } catch (localErr) {
        print('⚠️ Failed to load local growth logs: $localErr');
        return [];
      }
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAllGrowthLogs() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse("${Config.apiBaseUrl}/tree-growth-logs"),
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
          // Unexpected format -> return empty list so callers can fallback to local cache
          print('⚠️ TreeGrowthApi.fetchAllGrowthLogs: unexpected response format: $data');
          return <Map<String, dynamic>>[];
        }
      } else {
        return <Map<String, dynamic>>[];
      }
    } catch (e) {
      // Network or parsing error: log and return empty list so caller can use local cache
      print('⚠️ TreeGrowthApi.fetchAllGrowthLogs error: $e');
      return <Map<String, dynamic>>[];
    }
  }
}
