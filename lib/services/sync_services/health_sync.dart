import '../local database/health_db.dart';
import '../api/health_api.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../app_initializer.dart';
import 'dart:async';

class SyncHealth {
  Future<void> syncHealth() async {
    try {
      final hasInternet =
          await Connectivity().checkConnectivity() != ConnectivityResult.none;
      if (!hasInternet) {
        print('📴 Offline — health sync postponed');
        return;
      }

      final db = HealthDB();

      // 1) Pending deletes
      final deletes = await db.fetchPendingDeletes();
      for (final h in deletes) {
        if (AppInitializer.isAbortRequested) {
          print('⚠️ Aborting health sync due to connectivity loss');
          break;
        }
        try {
          final tu = h.tree_uuid ?? '';
          if (tu.isEmpty) {
            print('⚠️ Pending delete has no tree_uuid; skipping');
            continue;
          }

          try {
            List<Map<String, dynamic>> remote;
            try {
              remote = await HealthApi.fetchTreeHealthRecords(tu).timeout(const Duration(seconds: 10));
            } on TimeoutException {
              print('❌ fetchTreeHealthRecords timed out for $tu');
              continue;
            }
            // Try to match by recorded_at and disease id (best-effort)
            Map<String, dynamic>? match;
            for (final r in remote) {
              final recorded = (r['recorded_at'] ?? r['recordedAt'])?.toString() ?? '';
              final did = (r['disease_id'] ?? r['diseaseId'] ?? r['disease'])?.toString() ?? '';
              if (recorded.isNotEmpty && recorded == (h.recorded_at ?? '') && did == (h.diseaseId ?? '')) {
                match = r;
                break;
              }
            }

            if (match != null && (match['id'] != null || match['uuid'] != null)) {
              final id = (match['id'] ?? match['uuid']).toString();
              try {
                await HealthApi.deleteHealthRecord(id).timeout(const Duration(seconds: 10));
                await db.deleteHealthByTreeUuid(tu);
                print('✅ Deleted remote & local health for tree $tu');
              } on TimeoutException {
                print('❌ deleteHealthRecord timed out for $id');
              }
            } else {
              print('ℹ️ Could not resolve remote id for pending delete on tree $tu; skipping');
            }
          } catch (e) {
            print('⚠️ Failed to process pending delete for tree $tu: $e');
          }
        } catch (e) {
          print('⚠️ Error during health delete: $e');
        }
      }

      // 2) Pending updates
      final updates = await db.fetchPendingUpdates();
      for (final h in updates) {
        if (AppInitializer.isAbortRequested) {
          print('⚠️ Aborting health sync due to connectivity loss');
          break;
        }
        try {
          final tu = h.tree_uuid ?? '';
          if (tu.isEmpty) {
            print('⚠️ Pending update has no tree_uuid; skipping');
            continue;
          }

          try {
            List<Map<String, dynamic>> remote;
            try {
              remote = await HealthApi.fetchTreeHealthRecords(tu).timeout(const Duration(seconds: 10));
            } on TimeoutException {
              print('❌ fetchTreeHealthRecords timed out for $tu');
              continue;
            }
            Map<String, dynamic>? match;
            for (final r in remote) {
              final recorded = (r['recorded_at'] ?? r['recordedAt'])?.toString() ?? '';
              final did = (r['disease_id'] ?? r['diseaseId'] ?? r['disease'])?.toString() ?? '';
              if (recorded.isNotEmpty && recorded == (h.recorded_at ?? '') && did == (h.diseaseId ?? '')) {
                match = r;
                break;
              }
            }

            if (match != null && (match['id'] != null || match['uuid'] != null)) {
              final id = (match['id'] ?? match['uuid']).toString();
              try {
                final resp = await HealthApi.updateHealthRecord(
                  id: id,
                  treeUuid: h.tree_uuid ?? '',
                  diseaseId: int.tryParse(h.diseaseId ?? '') ?? 0,
                  date: h.recorded_at ?? '',
                  status: h.status ?? '',
                  treatment: h.treatment ?? '',
                ).timeout(const Duration(seconds: 10));
                if (resp['success'] == true || resp.containsKey('data')) {
                  await db.markAsSynced(h.tree_uuid ?? '');
                  print('✅ Synced health update for tree ${h.tree_uuid}');
                } else {
                  print('⚠️ Health update API returned unexpected response: $resp');
                }
              } catch (e) {
                print('❌ Health update failed for ${h.tree_uuid}: $e');
              }
            } else {
              print('ℹ️ Could not resolve remote id for pending update on tree $tu; skipping');
            }
          } catch (e) {
            print('⚠️ Failed to resolve remote id for update for tree $tu: $e');
          }
        } catch (e) {
          print('⚠️ Error processing pending health update: $e');
        }
      }

      // 3) New unsynced health records
      final unsynced = await db.fetchUnsyncedHealths();
      final newOnes = unsynced.where((h) => h.pendingUpdate == 0 && h.pendingDelete == 0).toList();
      for (final h in newOnes) {
        if (AppInitializer.isAbortRequested) {
          print('⚠️ Aborting health sync due to connectivity loss');
          break;
        }
        try {
          final resp = await HealthApi.createHealthRecord(
            treeUuid: h.tree_uuid ?? '',
            diseaseId: int.tryParse(h.diseaseId ?? '') ?? 0,
            date: h.recorded_at ?? '',
            status: h.status ?? '',
            treatment: h.treatment ?? '',
            imageFile: null,
          ).timeout(const Duration(seconds: 10));

          if (resp['success'] == true || resp.containsKey('data')) {
            await db.markAsSynced(h.tree_uuid ?? '');
          } else {
            print('⚠️ Create health API returned unexpected response: $resp');
          }
        } catch (e) {
          print('❌ Failed to sync health record for tree ${h.tree_uuid}: $e');
        }
      }
    } catch (e) {
      print('⚠️ syncHealth failed: $e');
    }
  }
}