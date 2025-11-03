import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config.dart';
import 'dart:io';

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
    File? imageFile,
  }) async {
    final uri = Uri.parse("${Config.apiBaseUrl}/health-records");
    var request = http.MultipartRequest('POST', uri);

    request.fields['tree_uuid'] = treeUuid;
    request.fields['disease_id'] = diseaseId.toString();
    request.fields['recorded_at'] = date;
    request.fields['status'] = status;
    request.fields['treatment'] = treatment;

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
        throw Exception(data['message'] ?? 'Failed to create health record');
      }
    } catch (e) {
      print(response.body);
      throw Exception('Failed to create health record');
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

  static Future<Map<String, dynamic>> updateHealthRecord({
    required String id,
    required String treeUuid,
    required int diseaseId,
    required String date,
    required String status,
    required String treatment,
    File? imageFile,
  }) async {
    final uri = Uri.parse("${Config.apiBaseUrl}/health-records/$id");
    var request = http.MultipartRequest(
      'POST',
      uri,
    ); // If backend expects PUT method:
    request.fields['_method'] = 'PUT'; // Laravel style method spoofing

    request.fields['tree_uuid'] = treeUuid;
    request.fields['disease_id'] = diseaseId.toString();
    request.fields['recorded_at'] = date;
    request.fields['status'] = status;
    request.fields['treatment'] = treatment;

    // ✅ Attach image only if user selected a new one
    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('thumbnail', imageFile.path),
      );
    }

    // ✅ Add headers (same as create)
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
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to update health record');
      }
    } catch (e) {
      throw Exception('Failed to update health record: ${response.body}');
    }
  }

  static Future<void> deleteHealthRecord(String id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.delete(
      Uri.parse("${Config.apiBaseUrl}/health-records/$id"),
      headers: {
        "Accept": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to delete health record: ${response.body}");
    }
  }
}
