import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config.dart';
import '../local database/disease_db.dart';
import '../api/disease_api.dart';
import '../app_initializer.dart';
import 'dart:async';

class SyncDiseases {
  Future<void> syncDiseases() async {
    try {
      final db = DiseaseDB();
      
      // 1) Handle pending deletes
      final deletes = await db.fetchPendingDeletes();
      for (final d in deletes) {
        if (AppInitializer.isAbortRequested) {
          print('⚠️ Aborting disease sync due to connectivity loss');
          break;
        }
        try {
          final id = d['uuid']?.toString() ?? d['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          try {
            await DiseaseApi.deleteDisease(id).timeout(const Duration(seconds: 10));
          } on TimeoutException {
            print('❌ deleteDisease timed out for $id');
            continue;
          }
          await db.deleteDisease(id);
          print('✅ Deleted disease: $id');
        } catch (e) {
          print('⚠️ Failed to delete disease: $e');
        }
      }
      
      // 2) Handle pending updates
      final updates = await db.fetchPendingUpdates();
      for (final d in updates) {
        if (AppInitializer.isAbortRequested) {
          print('⚠️ Aborting disease sync due to connectivity loss');
          break;
        }
        try {
          final id = d['uuid']?.toString() ?? d['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          try {
            await DiseaseApi.updateDisease(
            id: id,
            diseaseName: d['disease_name']?.toString() ?? '',
            symptoms: d['symptoms']?.toString() ?? '',
            remarks: d['remarks']?.toString() ?? '',
            ).timeout(const Duration(seconds: 10));
          } on TimeoutException {
            print('❌ updateDisease timed out for $id');
            continue;
          }
          await db.markAsSynced(id);
          print('✅ Synced disease update: $id');
        } catch (e) {
          print('⚠️ Failed to sync disease update: $e');
        }
      }
      
      // 3) Handle unsynced new diseases
      final unsynced = await db.fetchUnsyncedDiseases();
      for (final d in unsynced) {
        if (AppInitializer.isAbortRequested) {
          print('⚠️ Aborting disease sync due to connectivity loss');
          break;
        }
        try {
          final localUuid = d['uuid']?.toString() ?? '';
          
          SharedPreferences prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token');

          // Create the disease on the server
          http.Response response;
          try {
            response = await http.post(
            Uri.parse("${Config.apiBaseUrl}/diseases"),
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
              if (token != null) "Authorization": "Bearer $token",
            },
            body: jsonEncode({
              "diseaseName": d['disease_name']?.toString() ?? '',
              "symptoms": d['symptoms']?.toString() ?? '',
              "remarks": d['remarks']?.toString() ?? '',
            }),
            ).timeout(const Duration(seconds: 10));
          } on TimeoutException {
            print('❌ create disease http.post timed out for localUuid=$localUuid');
            continue;
          }

          if (response.statusCode == 200 || response.statusCode == 201) {
            final data = jsonDecode(response.body);
            final diseaseData = data['data'] ?? data;
            final serverUuid = diseaseData['uuid']?.toString();
            final serverId = diseaseData['id'];

            // Delete the local record with the temporary UUID
            await db.deleteDisease(localUuid);
            
            // Insert the new record with the server UUID
            await db.insertDisease({
              'id': serverId,
              'uuid': serverUuid,
              'disease_name': d['disease_name']?.toString() ?? '',
              'symptoms': d['symptoms']?.toString() ?? '',
              'remarks': d['remarks']?.toString() ?? '',
              'synced': 1,
              'pending_update': 0,
              'pending_delete': 0,
            });
            
            print('✅ Synced new disease: $serverUuid');
          } else {
            final data = jsonDecode(response.body);
            print('⚠️ Failed to sync new disease: ${data["message"] ?? "Unknown error"}');
          }
        } catch (e) {
          print('⚠️ Failed to sync new disease: $e');
        }
      }
      // Refresh remote disease list into local cache to ensure deletes/updates reflect
      try {
        List<Map<String, dynamic>> remoteDiseases;
        try {
          remoteDiseases = await DiseaseApi.fetchDiseases().timeout(const Duration(seconds: 10));
        } on TimeoutException {
          print('❌ fetchDiseases timed out');
          remoteDiseases = [];
        }
        if (remoteDiseases.isNotEmpty) {
          await db.saveDiseaseList(remoteDiseases);
          print('🔁 Refreshed local disease cache after sync (${remoteDiseases.length} items)');
        }
      } catch (e) {
        print('⚠️ Failed to refresh disease cache after sync: $e');
      }
    } catch (e) {
      print('⚠️ Disease sync error: $e');
    }
  }
}
