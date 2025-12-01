import '../local database/agro_db.dart';
import '../api/agrochemical_api.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SyncAgro {
  Future<void> syncAgro() async {
  try {
      final hasInternet =
          await Connectivity().checkConnectivity() != ConnectivityResult.none;
      if (!hasInternet) {
        print('📴 Offline — agro sync postponed');
        return;
      }

      final db = AgroDB();

      // 1) Pending deletes
      final deletes = await db.fetchPendingDeletes();
      print('🗑️ Found ${deletes.length} pending agrochemical deletes');
      for (final a in deletes) {
        try {
          final tu = a.tree_uuid ?? '';
          if (tu.isEmpty) {
            print('⚠️ Pending delete has no tree_uuid; skipping');
            continue;
          }

          try {
            // Fetch remote agrochemical records for this tree and try to match by applied_at + agrochemicalId/name
            final remote = await AgrochemicalApi.fetchAgrochemicals(treeUuid: tu);
            Map<String, dynamic>? match;
            for (final r in remote) {
              final applied = (r['applied_at'] ?? r['appliedAt'])?.toString() ?? '';
              final aid = (r['agrochemical_id'] ?? r['agrochemicalId'] ?? r['agrochemical'])?.toString() ?? '';
              if (applied.isNotEmpty && applied == (a.applied_at ?? '')) {
                // also ensure agrochemical id/name matches when available
                if ((aid.isNotEmpty && aid == (a.agrochemicalId ?? '')) || (r['agrochemical'] is Map && (r['agrochemical']['name'] ?? '') == (a.agrochemicalName ?? ''))) {
                  match = r;
                  break;
                }
              }
            }

            if (match != null && (match['id'] != null || match['uuid'] != null)) {
              final id = (match['id'] ?? match['uuid']).toString();
              await AgrochemicalApi.deleteAgrochemicalRecord(id);
              await db.deleteAgrochemicalByTreeUuid(tu);
              print('✅ Deleted remote & local agrochemical records for tree $tu');
            } else {
              print('ℹ️ Could not resolve remote id for pending delete on tree $tu; skipping');
            }
          } catch (e) {
            print('⚠️ Failed to process pending delete for tree $tu: $e');
          }
        } catch (e) {
          print('⚠️ Error during agrochemical delete: $e');
        }
      }

      // 2) Pending updates
      final updates = await db.fetchPendingUpdates();
      print('🔁 Found ${updates.length} pending agrochemical updates');
      for (final a in updates) {
        try {
          final tu = a.tree_uuid ?? '';
          if (tu.isEmpty) {
            print('⚠️ Pending update has no tree_uuid; skipping');
            continue;
          }

          try {
            final remote = await AgrochemicalApi.fetchAgrochemicals(treeUuid: tu);
            Map<String, dynamic>? match;
            for (final r in remote) {
              final applied = (r['applied_at'] ?? r['appliedAt'])?.toString() ?? '';
              final aid = (r['agrochemical_id'] ?? r['agrochemicalId'] ?? r['agrochemical'])?.toString() ?? '';
              if (applied.isNotEmpty && applied == (a.applied_at ?? '')) {
                if ((aid.isNotEmpty && aid == (a.agrochemicalId ?? '')) || (r['agrochemical'] is Map && (r['agrochemical']['name'] ?? '') == (a.agrochemicalName ?? ''))) {
                  match = r;
                  break;
                }
              }
            }

            if (match != null && (match['id'] != null || match['uuid'] != null)) {
              final id = (match['id'] ?? match['uuid']).toString();
              try {
                await AgrochemicalApi.updateAgrochemicalRecord(
                  record_uuid: id,
                  agrochemical_uuid: a.agrochemicalId ?? '',
                  tree_uuid: a.tree_uuid ?? '',
                  applied_at: a.applied_at ?? '',
                  description: a.description ?? '',
                );
                await db.markAsSynced(a.tree_uuid ?? '');
                print('✅ Synced agrochemical update for tree ${a.tree_uuid}');
              } catch (e) {
                print('❌ Agrochemical update failed for ${a.tree_uuid}: $e');
              }
            } else {
              print('ℹ️ Could not resolve remote id for pending update on tree $tu; skipping');
            }
          } catch (e) {
            print('⚠️ Failed to resolve remote id for update for tree $tu: $e');
          }
        } catch (e) {
          print('⚠️ Error processing pending agrochemical update: $e');
        }
      }

      // 3) New unsynced health records
      final unsynced = await db.fetchUnsyncedAgrochemicals();
      final newOnes = unsynced.where((h) => h.pendingUpdate == 0 && h.pendingDelete == 0).toList();
      print('🌱 Found ${newOnes.length} new unsynced agrochemical records');
      for (final h in newOnes) {
        try {
          final resp = await AgrochemicalApi.createAgrochemicalRecord(
            tree_uuid: h.tree_uuid ?? '',
            agrochemical_uuid: h.agrochemicalId ?? '',
            applied_at: h.applied_at ?? '',
            description: h.description ?? '',
          );

          // createAgrochemicalRecord returns a Map on success (or throws)
          if (resp['success'] == true || resp.containsKey('data')) {
            await db.markAsSynced(h.tree_uuid ?? '');
            print('✅ Synced new agrochemical record for tree ${h.tree_uuid}');
          } else {
            print('⚠️ Create agrochemical API returned unexpected response: $resp');
          }
        } catch (e) {
          print('❌ Failed to sync agrochemical record for tree ${h.tree_uuid}: $e');
        }
      }
    } catch (e) {
      print('⚠️ syncHealth failed: $e');
    }
  }
}