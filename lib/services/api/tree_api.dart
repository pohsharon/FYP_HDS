import 'dart:convert';
import 'dart:io';
import 'package:fyp_hbs/services/local%20database/species_db.dart';
import 'package:fyp_hbs/services/local%20database/tree_db.dart';
import '../../models/tree_model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../utils/connectivity_helper.dart';

class TreeApi {
  static Future<Map<String, dynamic>> createTree({
    required String speciesId,
    required String plantedAt,
    required double height,
    required double diameter,
    required String floweringPeriod,
    String? floweringStatus,
    File? imageFile,
    double? latitude,
    double? longitude,
    String? area,
    int? terrace,
    int? waterValve,
  }) async {
    final uri = Uri.parse("${Config.apiBaseUrl}/trees");
    var request = http.MultipartRequest('POST', uri);

    // Add fields
    request.fields['species_id'] = speciesId;
    request.fields['planted_at'] = plantedAt;
    request.fields['height'] = height.toString();
    request.fields['diameter'] = diameter.toString();
    request.fields['flowering_period'] = floweringPeriod;
    if (floweringStatus != null && floweringStatus.isNotEmpty) {
      request.fields['flowering_status'] = floweringStatus;
    }

    // Optional location and metadata
    if (latitude != null) request.fields['latitude'] = latitude.toString();
    if (longitude != null) request.fields['longitude'] = longitude.toString();
    if (area != null && area.isNotEmpty) request.fields['area'] = area;
    if (terrace != null) request.fields['terrace'] = terrace.toString();
    if (waterValve != null) request.fields['water_valve'] = waterValve.toString();

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
      // print(response.body);
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
        // print("📦 Loaded species from cache (offline)");
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
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            // Ensure code field is included if present
            return {
              'id': map['id'],
              'code': map['code'] ?? map['species_code'] ?? '',
              'name': map['name'] ?? map['title'] ?? map['label'] ?? map['value'] ?? '',
            };
          }
          if (item is String) return {'id': null, 'code': '', 'name': item};
          return {'id': null, 'code': '', 'name': item?.toString() ?? ''};
        }).toList();

        // 💾 Cache species locally for offline use (SharedPreferences)
        await prefs.setString('cached_species', jsonEncode(speciesList));

        // Also persist species into local SQLite for stronger offline lookup
        try {
          await SpeciesDB().saveSpeciesList(speciesList);
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
      // Try loading from cache as fallback
      final cachedSpecies = prefs.getString('cached_species');
      if (cachedSpecies != null) {
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

  static Future<Map<String, dynamic>> getTreeFloweringPeriod(String uuid) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final url = "${Config.apiBaseUrl}/trees/$uuid/flowering-period";
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
      throw Exception("Failed to fetch flowering period");
    }
  }

  /// Get the latest flowering status observation for a tree.
  /// Endpoint: GET /api/trees/{id}/flowering-status
  /// Returns a JSON object with `success` and `data` (see API contract).
  static Future<Map<String, dynamic>> getTreeFloweringStatus(String id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    // Ensure we call the endpoint with a numeric tree ID. If a UUID was
    // provided, try to resolve the numeric ID via `getTreeByUuid`.
    String resolvedId = id;
    if (int.tryParse(resolvedId) == null) {
      try {
        final srv = await getTreeByUuid(resolvedId);
        Map<String, dynamic>? tmap;
        if (srv is Map && srv.containsKey('data')) {
          final d = srv['data'];
          if (d is Map) tmap = Map<String, dynamic>.from(d);
        } else if (srv is Map) {
          tmap = Map<String, dynamic>.from(srv);
        }
        if (tmap != null && tmap.containsKey('id')) {
          final sid = tmap['id']?.toString();
          if (sid != null && int.tryParse(sid) != null) resolvedId = sid;
        }
      } catch (_) {
        // If resolution fails, keep original value — the server will return an error.
      }
    }

    final url = "${Config.apiBaseUrl}/trees/$resolvedId/flowering-status";
    final headers = {
      "Accept": "application/json",
      if (token != null) "Authorization": 'Bearer $token',
    };

    // Debug: print request info to help diagnose server 500s (remove in production)
    print('TreeApi.getTreeFloweringStatus --> GET $url');
    print('Headers: $headers');

    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      // Include response body in exception to aid debugging (server message or stack)
      String body = response.body;
      try {
        final data = jsonDecode(body);
        final message = (data is Map && data.containsKey('message')) ? data['message'] : body;
        throw Exception('Failed to fetch flowering status (status ${response.statusCode}): $message');
      } catch (_) {
        throw Exception('Failed to fetch flowering status (status ${response.statusCode}): $body');
      }
    }
  }

  /// Add a flowering status observation for a tree.
  /// Endpoint: POST /api/trees/{id}/observations
  /// Body: { "harvest_uuid": "<uuid>", "flowering_status": "A|B|C|D|X" }
  static Future<Map<String, dynamic>> addTreeFloweringObservation({
    required String id,
    required String harvestUuid,
    required String floweringStatus,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    // Resolve numeric id if caller passed a UUID
    String resolvedId = id;
    if (int.tryParse(resolvedId) == null) {
      try {
        final srv = await getTreeByUuid(resolvedId);
        Map<String, dynamic>? tmap;
        if (srv is Map && srv.containsKey('data')) {
          final d = srv['data'];
          if (d is Map) tmap = Map<String, dynamic>.from(d);
        } else if (srv is Map) {
          tmap = Map<String, dynamic>.from(srv);
        }
        if (tmap != null && tmap.containsKey('id')) {
          final sid = tmap['id']?.toString();
          if (sid != null && int.tryParse(sid) != null) resolvedId = sid;
        }
      } catch (_) {}
    }

    final uri = Uri.parse("${Config.apiBaseUrl}/trees/$resolvedId/observations");
    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        if (token != null) "Authorization": 'Bearer $token',
      },
      body: jsonEncode({
        'harvest_uuid': harvestUuid,
        'flowering_status': floweringStatus,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    // Debug: print request/response to help diagnose 422 or other errors
    try {
      print('TreeApi.addTreeFloweringObservation --> POST $uri');
      print('Request body: ${jsonEncode({'harvest_uuid': harvestUuid, 'flowering_status': floweringStatus})}');
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
    } catch (_) {}

    try {
      final data = jsonDecode(response.body);
      final message = (data is Map && data.containsKey('message')) ? data['message'] : data.toString();
      throw Exception('Failed to add flowering observation (status ${response.statusCode}): $message');
    } catch (_) {
      throw Exception('Failed to add flowering observation (status ${response.statusCode}): ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> updateTree({
    required String id,
    required String speciesId,
    required String plantedAt,
    required double height,
    required double diameter,
    required String floweringPeriod,
    String? floweringStatus,
    double? latitude,
    double? longitude,
    String? area,
    int? terrace,
    int? waterValve,
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
    if (floweringStatus != null && floweringStatus.isNotEmpty) {
      request.fields['flowering_status'] = floweringStatus;
    }
    if (area != null && area.isNotEmpty) request.fields['area'] = area;
    if (terrace != null) request.fields['terrace'] = terrace.toString();
    if (waterValve != null) request.fields['water_valve'] = waterValve.toString();
  // Preserve latitude/longitude when provided (some backends treat
  // missing coords as zero/null). Only send if non-null.
  if (latitude != null) request.fields['latitude'] = latitude.toString();
  if (longitude != null) request.fields['longitude'] = longitude.toString();

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
    String? floweringStatus,
    double? latitude,
    double? longitude,
    String? area,
    int? terrace,
    int? waterValve,
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
    if (floweringStatus != null && floweringStatus.isNotEmpty) {
      request.fields['flowering_status'] = floweringStatus;
    }
    if (area != null && area.isNotEmpty) request.fields['area'] = area;
    if (terrace != null) request.fields['terrace'] = terrace.toString();
    if (waterValve != null) request.fields['water_valve'] = waterValve.toString();

  if (latitude != null) request.fields['latitude'] = latitude.toString();
  if (longitude != null) request.fields['longitude'] = longitude.toString();

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
    // Check actual internet connectivity
    final hasInternet = await ConnectivityHelper.hasInternetConnection();
    // print('🌐 addTreeLocation - hasInternet: $hasInternet for tree: $treeUuid');

    if (!hasInternet) {
      // Save location locally with pending_update flag (upsert if row missing)
      // print('📴 Saving location offline: lat=$latitude, lng=$longitude');
      final treeDB = TreeDB();
      final updated = await treeDB.updateTreeByUuid(
        treeUuid,
        {
          'latitude': latitude,
          'longitude': longitude,
        },
        markPendingUpdate: true,
      );

      // If no existing row was updated, insert a stub row to carry the pending update
      if (updated == 0) {
        try {
          final stub = TreeModel(
            uuid: treeUuid,
            treeTag: 'Offline Tree',
            latitude: latitude,
            longitude: longitude,
            synced: 0,
            pendingUpdate: 1,
          );
          await treeDB.insertTree(stub);
          // print('ℹ️ Inserted stub tree row for offline location update');
        } catch (e) {
          print('⚠️ Failed to insert stub tree row: $e');
        }
      }

      // print('✅ Location saved offline with pending_update flag');
      throw Exception("Location saved offline, will sync when online");
    }

    // print('🌐 Saving location online to server...');
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
      // print('✅ Location saved to server successfully');
      return;
    } else {
      final data = jsonDecode(response.body);
      print('❌ Failed to save location: ${data["message"]}');
      throw Exception(data["message"] ?? "Failed to add tree location");
    }
  }

  /// Attach a label to a tree (server-side endpoint must accept JSON body with `label` and optional `color`).
  static Future<Map<String, dynamic>> attachLabel({
    required String treeId,
    required String label,
    String? color,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final uri = Uri.parse("${Config.apiBaseUrl}/trees/$treeId/labels");
      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          'label': label,
          if (color != null) 'color': color,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      final body = response.body;
      // Print server response for debugging (helps surface 500 errors)
      print('❌ attachLabel failed (status ${response.statusCode}): $body');

      try {
        final data = jsonDecode(body);
        throw Exception(data['message'] ?? 'Failed to attach label: $body');
      } catch (_) {
        throw Exception('Failed to attach label (status ${response.statusCode}): $body');
      }
    } catch (e) {
      throw Exception('Error attaching label: $e');
    }
  }

  /// Fetch labels attached to a specific tree
  /// Endpoint: GET /api/trees/{id}/labels
  static Future<Map<String, dynamic>> getTreeLabels({
    required String treeId,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final uri = Uri.parse("${Config.apiBaseUrl}/trees/$treeId/labels");
      final response = await http.get(
        uri,
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      final body = response.body;
      print('❌ getTreeLabels failed (status ${response.statusCode}): $body');
      try {
        final data = jsonDecode(body);
        throw Exception(data['message'] ?? 'Failed to fetch tree labels: $body');
      } catch (_) {
        throw Exception('Failed to fetch tree labels (status ${response.statusCode}): $body');
      }
    } catch (e) {
      throw Exception('Error fetching tree labels: $e');
    }
  }

  /// Fetch all available labels from the server
  /// Endpoint: GET /api/labels
  static Future<Map<String, dynamic>> getLabels() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final uri = Uri.parse("${Config.apiBaseUrl}/labels");
      final response = await http.get(
        uri,
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      final body = response.body;
      print('❌ getLabels failed (status ${response.statusCode}): $body');
      try {
        final data = jsonDecode(body);
        throw Exception(data['message'] ?? 'Failed to fetch labels: $body');
      } catch (_) {
        throw Exception('Failed to fetch labels (status ${response.statusCode}): $body');
      }
    } catch (e) {
      throw Exception('Error fetching labels: $e');
    }
  }

  /// Fetch trees attached to a specific label
  /// Endpoint: GET /api/labels/{labelId}/trees
  static Future<Map<String, dynamic>> getTreesByLabel({
    required String labelId,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final uri = Uri.parse("${Config.apiBaseUrl}/labels/$labelId/trees");
      final response = await http.get(
        uri,
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      final body = response.body;
      print('❌ getTreesByLabel failed (status ${response.statusCode}): $body');
      try {
        final data = jsonDecode(body);
        throw Exception(data['message'] ?? 'Failed to fetch trees by label: $body');
      } catch (_) {
        throw Exception('Failed to fetch trees by label (status ${response.statusCode}): $body');
      }
    } catch (e) {
      throw Exception('Error fetching trees by label: $e');
    }
  }

  /// Detach/delete a label from a tree
  /// Endpoint: DELETE /api/trees/{treeId}/labels/{labelId}
  static Future<void> deleteTreeLabel({
    required String treeId,
    required String labelId,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final uri = Uri.parse("${Config.apiBaseUrl}/trees/$treeId/labels/$labelId");
      final response = await http.delete(
        uri,
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      }

      final body = response.body;
      print('❌ deleteTreeLabel failed (status ${response.statusCode}): $body');
      try {
        final data = jsonDecode(body);
        throw Exception(data['message'] ?? 'Failed to delete tree label: $body');
      } catch (_) {
        throw Exception('Failed to delete tree label (status ${response.statusCode}): $body');
      }
    } catch (e) {
      throw Exception('Error deleting tree label: $e');
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

  /// Add a harvest record for a tree.
  /// Endpoint: POST /api/trees/{id}/harvest-records
  /// Accepts optional fields: harvest_uuid (uuid), harvest_date (date),
  /// num_of_fruits (integer), weight (numeric), spoilt (boolean).
  static Future<Map<String, dynamic>> addHarvestRecord({
    required String id,
    String? harvestUuid,
    String? harvestDate,
    int? numOfFruits,
    double? weight,
    bool? spoilt,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // Resolve numeric id if caller passed a UUID
      String resolvedId = id;
      if (int.tryParse(resolvedId) == null) {
        try {
          final srv = await getTreeByUuid(resolvedId);
          Map<String, dynamic>? tmap;
          if (srv is Map && srv.containsKey('data')) {
            final d = srv['data'];
            if (d is Map) tmap = Map<String, dynamic>.from(d);
          } else if (srv is Map) {
            tmap = Map<String, dynamic>.from(srv);
          }
          if (tmap != null && tmap.containsKey('id')) {
            final sid = tmap['id']?.toString();
            if (sid != null && int.tryParse(sid) != null) resolvedId = sid;
          }
        } catch (_) {}
      }

      final uri = Uri.parse("${Config.apiBaseUrl}/trees/$resolvedId/harvest-records");

      final Map<String, dynamic> payload = {};
      if (harvestUuid != null) payload['harvest_uuid'] = harvestUuid;
      if (harvestDate != null) payload['harvest_date'] = harvestDate;
      if (numOfFruits != null) payload['num_of_fruits'] = numOfFruits;
      if (weight != null) payload['weight'] = weight;
      if (spoilt != null) payload['spoilt'] = spoilt;

      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          if (token != null) "Authorization": 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      // Debug prints to aid diagnosing 422/validation errors
      try {
        print('TreeApi.addHarvestRecord --> POST $uri');
        print('Request body: ${jsonEncode(payload)}');
        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');
      } catch (_) {}

      try {
        final data = jsonDecode(response.body);
        final message = (data is Map && data.containsKey('message')) ? data['message'] : data.toString();
        throw Exception('Failed to add harvest record (status ${response.statusCode}): $message');
      } catch (_) {
        throw Exception('Failed to add harvest record (status ${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('Error adding harvest record: $e');
    }
  }

  /// Fetch harvest records for a tree.
  /// Endpoint: GET /api/trees/{id}/harvest-records
  /// Returns a Map with `success` and `data` containing `tree_id`, `tree_uuid`,
  /// `harvest_records` list and `pagination` meta (matches server shape).
  static Future<Map<String, dynamic>> fetchHarvestRecords({
    required String id,
    int page = 1,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    // Resolve numeric id if caller passed a UUID
    String resolvedId = id;
    if (int.tryParse(resolvedId) == null) {
      try {
        final srv = await getTreeByUuid(resolvedId);
        Map<String, dynamic>? tmap;
        if (srv is Map && srv.containsKey('data')) {
          final d = srv['data'];
          if (d is Map) tmap = Map<String, dynamic>.from(d);
        } else if (srv is Map) {
          tmap = Map<String, dynamic>.from(srv);
        }
        if (tmap != null && tmap.containsKey('id')) {
          final sid = tmap['id']?.toString();
          if (sid != null && int.tryParse(sid) != null) resolvedId = sid;
        }
      } catch (_) {}
    }

    final uri = Uri.parse("${Config.apiBaseUrl}/trees/$resolvedId/harvest-records?page=$page");

    final response = await http.get(
      uri,
      headers: {
        "Accept": "application/json",
        if (token != null) "Authorization": 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        return {'success': true, 'data': decoded};
      } catch (e) {
        throw Exception('Failed to parse harvest records: ${e.toString()}');
      }
    }

    // Debug: surface server response for easier diagnosis
    try {
      print('TreeApi.fetchHarvestRecords --> GET $uri');
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
    } catch (_) {}

    try {
      final decoded = jsonDecode(response.body);
      final message = (decoded is Map && decoded.containsKey('message')) ? decoded['message'] : response.body;
      throw Exception('Failed to fetch harvest records (status ${response.statusCode}): $message');
    } catch (_) {
      throw Exception('Failed to fetch harvest records (status ${response.statusCode})');
    }
  }
}
