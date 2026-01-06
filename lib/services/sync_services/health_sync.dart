import '../local database/health_db.dart';
import '../api/health_api.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
        try {
          final tu = h.tree_uuid ?? '';
          if (tu.isEmpty) {
            print('⚠️ Pending delete has no tree_uuid; skipping');
            continue;
          }

          try {
            final remote = await HealthApi.fetchTreeHealthRecords(tu);
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
              await HealthApi.deleteHealthRecord(id);
              await db.deleteHealthByTreeUuid(tu);
              print('✅ Deleted remote & local health for tree $tu');
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
        try {
          final tu = h.tree_uuid ?? '';
          if (tu.isEmpty) {
            print('⚠️ Pending update has no tree_uuid; skipping');
            continue;
          }

          try {
            final remote = await HealthApi.fetchTreeHealthRecords(tu);
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
                );
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
        try {
          final resp = await HealthApi.createHealthRecord(
            treeUuid: h.tree_uuid ?? '',
            diseaseId: int.tryParse(h.diseaseId ?? '') ?? 0,
            date: h.recorded_at ?? '',
            status: h.status ?? '',
            treatment: h.treatment ?? '',
            imageFile: null,
          );

          if (resp['success'] == true || resp.containsKey('data')) {
            await db.markAsSynced(h.tree_uuid ?? '');
            print('✅ Synced new health record for tree ${h.tree_uuid}');
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