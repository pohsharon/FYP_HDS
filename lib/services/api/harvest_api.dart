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
  static Future<Map<String, dynamic>> fetchDaySummary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final uri = Uri.parse('${Config.apiBaseUrl}/harvests/summary/day');
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
      throw Exception('Failed to fetch day summary: ${e.toString()}');
    }
  }

  /// Fetch this week's summary from `/harvests/summary/week`.
  /// Returns the `data` object (contains `from`, `to`, `totals`).
  static Future<Map<String, dynamic>> fetchWeekSummary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final uri = Uri.parse('${Config.apiBaseUrl}/harvests/summary/week');
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
}
