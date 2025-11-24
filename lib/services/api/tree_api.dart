import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fyp_hbs/services/local_db.dart';
import '../../config.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
      print(response.body);
      throw Exception('Failed to create tree: ${response.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchSpecies() async {
    final prefs = await SharedPreferences.getInstance();

    // Check connectivity status
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = connectivityResult == ConnectivityResult.none;

    // 📴 OFFLINE MODE: load cached species
    if (isOffline) {
      final cachedSpecies = prefs.getString('cached_species');
      if (cachedSpecies != null) {
        print("📦 Loaded species from cache (offline)");
        final List<dynamic> decodedList = jsonDecode(cachedSpecies);
        return decodedList.map<Map<String, dynamic>>((item) {
          return Map<String, dynamic>.from(item);
        }).toList();
      } else {
        print("⚠️ No cached species available (offline)");
        return [];
      }
    }

    // 🌐 ONLINE MODE: fetch from API
    try {
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
        List<dynamic> items;
        if (decoded is Map && decoded.containsKey('data')) {
          items = decoded['data'];
        } else if (decoded is List) {
          items = decoded;
        } else {
          throw Exception('Unexpected response format for species');
        }

        final speciesList = items.map<Map<String, dynamic>>((item) {
          if (item is Map) return Map<String, dynamic>.from(item);
          if (item is String) return {'id': null, 'name': item};
          return {'id': null, 'name': item?.toString() ?? ''};
        }).toList();

        // 💾 Cache species locally for offline use (SharedPreferences)
        await prefs.setString('cached_species', jsonEncode(speciesList));

        // Also persist species into local SQLite for stronger offline lookup
        try {
          await LocalDB.instance.saveSpeciesList(speciesList);
          print('✅ Species saved to local DB (${speciesList.length})');
        } catch (e) {
          print('⚠️ Failed to save species to local DB: $e');
        }

        return speciesList;
      } else {
        final message =
            (decoded is Map)
                ? decoded["message"] ?? "Failed to fetch species"
                : "Failed to fetch species";
        throw Exception(message);
      }
    } catch (e) {
      print("⚠️ Error fetching species online: $e");

      // Try loading from cache as fallback
      final cachedSpecies = prefs.getString('cached_species');
      if (cachedSpecies != null) {
        print("📦 Using cached species as fallback");
        final List<dynamic> decodedList = jsonDecode(cachedSpecies);
        return decodedList.map<Map<String, dynamic>>((item) {
          return Map<String, dynamic>.from(item);
        }).toList();
      } else {
        throw Exception("Error fetching species and no cache available");
      }
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

    // Aggregate pages if the server paginates results. Some backends ignore
    // the `page=all` query and still return paginated responses, so fetch
    // page-by-page until we've collected all items.
    try {
      int page = 1;
      final List<Map<String, dynamic>> allItems = [];

      while (true) {
        final response = await http.get(
          Uri.parse("${Config.apiBaseUrl}/trees?page=$page"),
          headers: {
            "Accept": "application/json",
            if (token != null) "Authorization": "Bearer $token",
          },
        );

        if (response.statusCode != 200) {
          // Try to extract message from body if possible
          try {
            final decodedErr = jsonDecode(response.body);
            throw Exception(decodedErr['message'] ?? 'Failed to fetch trees');
          } catch (_) {
            throw Exception('Failed to fetch trees (status ${response.statusCode})');
          }
        }

        final decoded = jsonDecode(response.body);

        // Normalize different response shapes to a list of items
        List<dynamic> items = [];
        if (decoded is Map && decoded.containsKey('data')) {
          final data = decoded['data'];
          if (data is Map && data.containsKey('data')) {
            items = data['data'];
          } else if (data is List) {
            items = data;
          }
        } else if (decoded is List) {
          items = decoded;
        }

        if (items.isEmpty) {
          break;
        }

        for (final it in items) {
          if (it is Map) allItems.add(Map<String, dynamic>.from(it));
        }

        // If response includes pagination meta, stop when we've reached last_page
        int? lastPage;
        try {
          if (decoded is Map) {
            final meta = decoded['meta'] ?? (decoded['data'] is Map ? decoded['data']['meta'] : null);
            if (meta is Map && meta.containsKey('last_page')) {
              lastPage = (meta['last_page'] is int) ? meta['last_page'] : int.tryParse(meta['last_page']?.toString() ?? '');
            }
          }
        } catch (_) {}

        if (lastPage != null) {
          if (page >= lastPage) break;
        }

        page += 1;
      }

      // Return in the same shape expected by TreeRepository: { 'data': { 'data': [...] } }
      return {'data': {'data': allItems}};
    } catch (e) {
      throw Exception('Failed to fetch all trees: $e');
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

  static Future<Map<String, dynamic>> updateTree({
    required String id,
    required String speciesId,
    required String plantedAt,
    required double height,
    required double diameter,
    required String floweringPeriod,
    File? imageFile,
  }) async {
    final uri = Uri.parse("${Config.apiBaseUrl}/trees/$id");
    var request = http.MultipartRequest("POST", uri);

    request.fields['_method'] = 'PUT';
    request.fields['species_id'] = speciesId;
    request.fields['planted_at'] = plantedAt;
    request.fields['height'] = height.toString();
    request.fields['diameter'] = diameter.toString();
    request.fields['flowering_period'] = floweringPeriod;

    // If user uploaded new image → send file
    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('thumbnail', imageFile.path),
      );
    }
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    request.headers['Accept'] = 'application/json';
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    try {
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(data);
      } else {
        final msg = (data is Map && data['message'] != null) ? data['message'].toString() : 'Failed to update tree';
        throw Exception(msg);
      }
    } catch (e) {
      // Return a concise error instead of printing the full server response body
      String body = response.body;
      try {
        final parsed = jsonDecode(body);
        if (parsed is Map && parsed['message'] != null) {
          throw Exception(parsed['message'].toString());
        }
      } catch (_) {}
      throw Exception('Failed to update tree (status ${response.statusCode})');
    }
  }

  /// Update a tree using its UUID (fallback when numeric id is not available)
  static Future<Map<String, dynamic>> updateTreeByUuid({
    required String uuid,
    required String speciesId,
    required String plantedAt,
    required double height,
    required double diameter,
    required String floweringPeriod,
    File? imageFile,
  }) async {
    final uri = Uri.parse("${Config.apiBaseUrl}/trees/uuid/$uuid");
    var request = http.MultipartRequest("POST", uri);

    request.fields['_method'] = 'PUT';
    request.fields['species_id'] = speciesId;
    request.fields['planted_at'] = plantedAt;
    request.fields['height'] = height.toString();
    request.fields['diameter'] = diameter.toString();
    request.fields['flowering_period'] = floweringPeriod;

    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('thumbnail', imageFile.path),
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    request.headers['Accept'] = 'application/json';
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    try {
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(data);
      } else {
        final msg = (data is Map && data['message'] != null) ? data['message'].toString() : 'Failed to update tree by uuid';
        throw Exception(msg);
      }
    } catch (e) {
      // Keep logs concise: attempt to extract server message, else provide status
      String body = response.body;
      try {
        final parsed = jsonDecode(body);
        if (parsed is Map && parsed['message'] != null) {
          throw Exception(parsed['message'].toString());
        }
      } catch (_) {}
      throw Exception('Failed to update tree by uuid (status ${response.statusCode})');
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
