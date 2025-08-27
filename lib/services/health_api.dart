import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class HealthApi {
  static Future<List<Map<String, dynamic>>> fetchDiseases() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse("${Config.apiBaseUrl}/diseases"),
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
      throw Exception("Failed to fetch diseases");
    }
  }

  static Future<Map<String, dynamic>> createHealthRecord({
    required String treeUuid,
    required int diseaseId,
    required String date,
    required String status,
    required String treatment,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse("${Config.apiBaseUrl}/health-records"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "tree_uuid": treeUuid,
          "disease_id": diseaseId,
          "date": date,
          "status": status,
          "treatment": treatment,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data["message"] ?? "Failed to create health record");
      }
    } catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  static Future<List<Map<String, dynamic>>> fetchHealthRecords(
    String treeUuid,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse("${Config.apiBaseUrl}/trees/$treeUuid/health-records"),
      headers: {
        "Accept": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data["data"]);
    } else {
      throw Exception("Failed to fetch health records: ${response.body}");
    }
  }

  static Future<List<Map<String, dynamic>>> fetchTreeHealthRecords(
    String treeUuid,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse("${Config.apiBaseUrl}/trees/$treeUuid/health-records"),
      headers: {
        "Accept": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data["data"]);
    } else {
      throw Exception("Failed to fetch health records: ${response.body}");
    }
  }

  static Future<void> updateHealthRecord({
    required String id,
    required String treeUuid,
    required int diseaseId,
    required String date,
    required String status,
    required String treatment,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.put(
      Uri.parse('${Config.apiBaseUrl}/health-records/$id'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'tree_uuid': treeUuid,
        'disease_id': diseaseId,
        'recorded_at': date,
        'status': status,
        'treatment': treatment,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update health record: ${response.body}');
    }
  }
}
