import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config.dart';

class HarvestApi {
  /// Fetch overall harvest summary (totals) from the server.
  /// Endpoint: GET {Config.apiBaseUrl}/harvests/summary
  /// Expected response shape:
  /// {
  ///   "totals": { "spoilt_weight": "0", "not_spoilt_weight": "250.00", "spoilt_fruits": 0, "not_spoilt_fruits": 12 }
  /// }
  /// If `days == 0` fetches today's summary at `/harvests/summary/today`.
  /// Otherwise calls `/harvests/summary` optionally with `?days=<n>`.
  static Future<Map<String, dynamic>> fetchSummary({int? days}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      Uri uri;
      if (days != null && days == 0) {
        uri = Uri.parse('${Config.apiBaseUrl}/harvests/summary/today');
      } else if (days != null) {
        uri = Uri.parse('${Config.apiBaseUrl}/harvests/summary?days=$days');
      } else {
        uri = Uri.parse('${Config.apiBaseUrl}/harvests/summary');
      }

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (decoded is Map && decoded.containsKey('totals')) {
          return Map<String, dynamic>.from(decoded['totals']);
        }
        // Fallback: if API returns totals under data or returns totals directly
        if (decoded is Map && decoded.containsKey('data') && decoded['data'] is Map && decoded['data'].containsKey('totals')) {
          return Map<String, dynamic>.from(decoded['data']['totals']);
        }
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        throw Exception('Unexpected response format');
      } else {
        final message = (decoded is Map) ? (decoded['message'] ?? decoded['error'] ?? response.body) : response.body;
        throw Exception(message);
      }
    } catch (e) {
      throw Exception('Failed to fetch harvest summary: ${e.toString()}');
    }
  }
  
  /// Fetch today's summary from `/harvests/summary/day`.
  /// Returns the `data` object from the API (contains `date` and `totals`).
  static Future<Map<String, dynamic>> fetchDaySummary({String? date}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final uri = (date != null && date.isNotEmpty)
          ? Uri.parse('${Config.apiBaseUrl}/harvests/summary/day?date=${Uri.encodeQueryComponent(date)}')
          : Uri.parse('${Config.apiBaseUrl}/harvests/summary/day');
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (decoded is Map && decoded.containsKey('data')) {
          final dataMap = Map<String, dynamic>.from(decoded['data']);
          // Normalize date field to YYYY-MM-DD when present
          try {
            if (dataMap.containsKey('date') && dataMap['date'] != null) {
              final raw = dataMap['date'].toString();
              final parsed = DateTime.tryParse(raw);
              if (parsed != null) {
                dataMap['date'] = parsed.toIso8601String().split('T').first;
              } else if (RegExp(r"^\\d{4}-\\d{2}-\\d{2}").hasMatch(raw)) {
                // already in YYYY-MM-DD or starts with it; trim to date part
                dataMap['date'] = raw.substring(0, 10);
              }
            }
          } catch (_) {}

          return dataMap;
        }
        throw Exception('Unexpected response format');
      }

      final message = (decoded is Map) ? (decoded['message'] ?? decoded['error'] ?? response.body) : response.body;
      throw Exception(message);
    } catch (e) {
      throw Exception('Failed to fetch day summary: ${e.toString()}');
    }
  }

  /// Fetch this week's summary from `/harvests/summary/week`.
  /// Optionally accept `from` and `to` (YYYY-MM-DD) to request a specific week range.
  /// Returns the `data` object (contains `from`, `to`, `totals`).
  static Future<Map<String, dynamic>> fetchWeekSummary({String? from, String? to}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final uri = (from != null && from.isNotEmpty && to != null && to.isNotEmpty)
          ? Uri.parse('${Config.apiBaseUrl}/harvests/summary/week?from=${Uri.encodeQueryComponent(from)}&to=${Uri.encodeQueryComponent(to)}')
          : Uri.parse('${Config.apiBaseUrl}/harvests/summary/week');
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (decoded is Map && decoded.containsKey('data')) {
          final dataMap = Map<String, dynamic>.from(decoded['data']);
          // Normalize date bounds if present
          try {
            if (dataMap.containsKey('from') && dataMap['from'] != null) {
              final parsedFrom = DateTime.tryParse(dataMap['from'].toString());
              if (parsedFrom != null) dataMap['from'] = parsedFrom.toIso8601String().split('T').first;
            }
            if (dataMap.containsKey('to') && dataMap['to'] != null) {
              final parsedTo = DateTime.tryParse(dataMap['to'].toString());
              if (parsedTo != null) dataMap['to'] = parsedTo.toIso8601String().split('T').first;
            }
          } catch (_) {}
          return dataMap;
        }
        throw Exception('Unexpected response format');
      }

      final message = (decoded is Map) ? (decoded['message'] ?? decoded['error'] ?? response.body) : response.body;
      throw Exception(message);
    } catch (e) {
      throw Exception('Failed to fetch week summary: ${e.toString()}');
    }
  }

  /// Fetch season summary from `/harvests/summary/season`.
  static Future<Map<String, dynamic>> fetchSeasonSummary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final uri = Uri.parse('${Config.apiBaseUrl}/harvests/summary/season');
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (decoded is Map && decoded.containsKey('data')) {
          return Map<String, dynamic>.from(decoded['data']);
        }
        throw Exception('Unexpected response format');
      }

      final message = (decoded is Map) ? (decoded['message'] ?? decoded['error'] ?? response.body) : response.body;
      throw Exception(message);
    } catch (e) {
      throw Exception('Failed to fetch season summary: ${e.toString()}');
    }
  }

  /// Fetch a harvest summary for a specific date range.
  /// Endpoint: GET {Config.apiBaseUrl}/harvests/details?from=YYYY-MM-DD&to=YYYY-MM-DD
  /// Expected response shape:
  /// {
  ///   "success": true,
  ///   "data": { "from": "2026-03-23", "to": "2026-03-23", "details": [ ... ] }
  /// }
  static Future<Map<String, dynamic>> fetchRangeSummary({required String from, required String to}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final uri = Uri.parse('${Config.apiBaseUrl}/harvests/details?from=$from&to=$to');

      // log request for debugging when UI shows no records
      try { // ignore: avoid_print
        print('GET ${uri.toString()}');
      } catch (_) {}

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      // log response for debugging
      try { // ignore: avoid_print
        print('Response ${response.statusCode}: ${response.body}');
      } catch (_) {}

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (decoded is Map && decoded.containsKey('data')) {
          final dataMap = Map<String, dynamic>.from(decoded['data']);
          dataMap['_raw_body'] = response.body;
          return dataMap;
        }
        // Some APIs may return the payload directly under `details` or as the whole map
        if (decoded is Map) {
          final m = Map<String, dynamic>.from(decoded);
          m['_raw_body'] = response.body;
          return m;
        }
        throw Exception('Unexpected response format');
      }

      final message = (decoded is Map) ? (decoded['message'] ?? decoded['error'] ?? response.body) : response.body;
      throw Exception(message);
    } catch (e) {
      throw Exception('Failed to fetch range summary: ${e.toString()}');
    }
  }

  /// Fetch the currently active harvest event from the server.
  /// Endpoint: GET {Config.apiBaseUrl}/harvests/active
  /// Returns the `data` object of the response when present.
  static Future<Map<String, dynamic>> fetchActiveHarvest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final uri = Uri.parse('${Config.apiBaseUrl}/harvests/active');

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        // API may return different shapes: { data: {...} } OR { data: [ ... ] } OR top-level Map OR top-level List
        if (decoded is Map) {
          if (decoded.containsKey('data')) {
            final data = decoded['data'];
            if (data is Map) return Map<String, dynamic>.from(data);
            if (data is List && data.isNotEmpty && data.first is Map) return Map<String, dynamic>.from(data.first);
            throw Exception('No active harvest data found');
          }
          // If the map itself represents the active harvest
          return Map<String, dynamic>.from(decoded);
        }

        if (decoded is List) {
          if (decoded.isNotEmpty && decoded.first is Map) return Map<String, dynamic>.from(decoded.first);
          throw Exception('No active harvest found in list');
        }

        throw Exception('Unexpected response format: ${decoded.runtimeType}');
      }

      final message = (decoded is Map) ? (decoded['message'] ?? decoded['error'] ?? response.body) : response.body;
      throw Exception(message);
    } catch (e) {
      throw Exception('Failed to fetch active harvest: ${e.toString()}');
    }
  }

  /// Create a harvest record for a tree.
  /// Endpoint: POST {Config.apiBaseUrl}/trees/{id}/harvest-records
  /// Body: {
  ///   harvest_uuid: string,
  ///   tree_uuid: string, // optional but accepted by backend
  ///   harvest_date: string (YYYY-MM-DD) | null,
  ///   num_of_fruits: int,
  ///   weight: number | null,
  ///   spoilt: bool
  /// }
  static Future<Map<String, dynamic>> createHarvestRecord({
    required String treeId,
    required String harvestUuid,
    String? treeUuid,
    String? harvestDate,
    int? numOfFruits,
    double? weight,
    bool? spoilt,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final uri = Uri.parse('${Config.apiBaseUrl}/trees/$treeId/harvest-records');

      final body = <String, dynamic>{};
      body['harvest_uuid'] = harvestUuid;
      if (treeUuid != null) body['tree_uuid'] = treeUuid;
      if (harvestDate != null && harvestDate.isNotEmpty) body['harvest_date'] = harvestDate;
      body['num_of_fruits'] = numOfFruits ?? 0;
      if (weight != null) body['weight'] = weight;
      body['spoilt'] = spoilt ?? false;

      final response = await http.post(uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      // Helpful debug when server returns validation errors
      try { // ignore: avoid_print
        print('HarvestApi.createHarvestRecord --> POST ${uri.toString()}');
        print('Request body: ${jsonEncode(body)}');
        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');
      } catch (_) {}

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        throw Exception('Unexpected response format');
      }

      final message = (decoded is Map) ? (decoded['message'] ?? decoded['error'] ?? response.body) : response.body;
      throw Exception('Failed to create harvest record (status ${response.statusCode}): $message');
    } catch (e) {
      throw Exception('Failed to create harvest record: ${e.toString()}');
    }
  }

  /// Update a harvest record for a tree.
  /// Calls: PUT {Config.apiBaseUrl}/trees/{id}/harvest-records/{harvestUuid}
  /// Body: any of { harvest_date, num_of_fruits, weight, spoilt }
  static Future<Map<String, dynamic>> updateHarvestRecord({
    required String treeId,
    required String harvestUuid,
    DateTime? harvestDate,
    int? numOfFruits,
    double? weight,
    bool? spoilt,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final uri = Uri.parse('${Config.apiBaseUrl}/trees/$treeId/harvest-records/$harvestUuid');

      final body = <String, dynamic>{};
      if (harvestDate != null) body['harvest_date'] = harvestDate.toIso8601String();
      if (numOfFruits != null) body['num_of_fruits'] = numOfFruits;
      if (weight != null) body['weight'] = weight;
      if (spoilt != null) body['spoilt'] = spoilt;

      final response = await http.put(uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        throw Exception('Unexpected response format');
      }

      final message = (decoded is Map) ? (decoded['message'] ?? decoded['error'] ?? response.body) : response.body;
      throw Exception(message);
    } catch (e) {
      throw Exception('Failed to update harvest record: ${e.toString()}');
    }
  }

  /// Delete a harvest record for a tree.
  /// Calls: DELETE {Config.apiBaseUrl}/trees/{id}/harvest-records/{harvestUuid}
  /// Returns the decoded JSON response on success.
  static Future<Map<String, dynamic>> deleteHarvestRecord({
    required String treeId,
    required String harvestUuid,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final uri = Uri.parse('${Config.apiBaseUrl}/trees/$treeId/harvest-records/$harvestUuid');

      final response = await http.delete(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        throw Exception('Unexpected response format');
      }

      final message = (decoded is Map) ? (decoded['message'] ?? decoded['error'] ?? response.body) : response.body;
      throw Exception(message);
    } catch (e) {
      throw Exception('Failed to delete harvest record: ${e.toString()}');
    }
  }
}
