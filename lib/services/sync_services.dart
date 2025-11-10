import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_db.dart';
import 'api/tree_api.dart';

class SyncService {
  final LocalDB _localDB = LocalDB.instance;
  bool _isRunning = false;
  DateTime? _lastRun;

  bool get isRunning => _isRunning;

  Future<void> syncUnsyncedTrees() async {
    final now = DateTime.now();
    // 🕒 Prevent duplicate runs
    if (_lastRun != null && now.difference(_lastRun!).inMilliseconds < 1200) {
      print('⏱️ Sync called too soon — skipping');
      return;
    }
    if (_isRunning) {
      print('🔁 Sync already running — skipping');
      return;
    }

    _isRunning = true;
    _lastRun = now;

    try {
      // 🔌 Step 1: Check connection (ensure actual internet connectivity)
      final hasInternet = await Connectivity().checkConnectivity() != ConnectivityResult.none;
      if (!hasInternet) {
        print('📴 Offline — sync postponed');
        return;
      }

      // 🧹 STEP 2: Handle pending deletes
      final deletes = await _localDB.fetchPendingDeletes();
      print('🗑 Found ${deletes.length} pending deletes');
      for (final t in deletes) {
        try {
          if (t.id == null) {
            print('⚠️ Cannot delete remote for ${t.uuid} because id is null');
            continue;
          }
          // TreeApi.deleteTree throws on failure; it returns void on success
          await TreeApi.deleteTree(t.id.toString());
          await _localDB.deleteTreeByUuid(t.uuid);
          print('✅ Deleted remote & local: ${t.uuid}');
        } catch (e) {
          print('⚠️ Error deleting ${t.uuid}: $e');
        }
      }

      // 📝 STEP 3: Handle pending updates
      final updates = await _localDB.fetchPendingUpdates();
      print('🧩 Found ${updates.length} pending updates');
      for (final t in updates) {
        try {
          // Prefer updating by numeric id when available, but fall back to uuid endpoint
          bool updated = false;
          if (t.id != null) {
            try {
              final resp = await TreeApi.updateTree(
                id: t.id.toString(),
                speciesId: t.speciesId ?? '',
                plantedAt: t.plantedAt?.toIso8601String() ?? '',
                height: t.height ?? 0.0,
                diameter: t.diameter ?? 0.0,
                floweringPeriod: t.floweringPeriod?.toString() ?? '',
                imageFile: t.imageFile,
              );
              if (resp['success'] == true || resp.containsKey('data')) {
                await _localDB.clearPendingUpdate(t.uuid);
                print('✅ Synced update by id: ${t.uuid}');
                updated = true;
              } else {
                print('⚠️ Server rejected update by id for ${t.uuid}');
              }
            } catch (e) {
              final msg = e.toString();
              if (msg.contains('No query results') || msg.contains('NotFoundHttpException') || msg.contains('404') || msg.contains('Not Found')) {
                print('ℹ️ Update by id returned 404/not-found for ${t.uuid}; will try resolving by uuid');
              } else {
                print('⚠️ Update by id failed for ${t.uuid}: $e');
              }
            }
          }

          if (!updated) {
            // Try resolving server numeric id via GET /trees/uuid/{uuid}
            try {
              final remote = await TreeApi.getTreeByUuid(t.uuid);
              // remote may be the tree object, or contain 'data'
              Map<String, dynamic> treeObj = {};
              if (remote.containsKey('data') && remote['data'] is Map) {
                treeObj = Map<String, dynamic>.from(remote['data']);
              } else {
                treeObj = Map<String, dynamic>.from(remote);
              }

              final serverId = treeObj['id']?.toString() ?? treeObj['server_id']?.toString();
              if (serverId != null && serverId.isNotEmpty) {
                final resp3 = await TreeApi.updateTree(
                  id: serverId,
                  speciesId: t.speciesId ?? '',
                  plantedAt: t.plantedAt?.toIso8601String() ?? '',
                  height: t.height ?? 0.0,
                  diameter: t.diameter ?? 0.0,
                  floweringPeriod: t.floweringPeriod?.toString() ?? '',
                  imageFile: t.imageFile,
                );
                if (resp3['success'] == true || resp3.containsKey('data')) {
                  await _localDB.clearPendingUpdate(t.uuid);
                  print('✅ Synced update by resolved server id: ${t.uuid} -> $serverId');
                  updated = true;
                } else {
                  print('⚠️ Server rejected update for resolved id $serverId for ${t.uuid}');
                }
              } else {
                print('⚠️ Could not resolve server id for uuid ${t.uuid}');
              }
            } catch (e) {
              final msg = e.toString();
              if (msg.contains('No query results') || msg.contains('NotFoundHttpException') || msg.contains('404') || msg.contains('MethodNotAllowedHttpException')) {
                print('ℹ️ Could not resolve server id or update for ${t.uuid}: ${msg.split("\n").first}');
              } else {
                print('⚠️ Failed to resolve server id/update for ${t.uuid}: $e');
              }
            }
          }

          if (!updated) {
            print('⚠️ Update failed for ${t.uuid}: unable to sync by id or uuid');
          }
        } catch (e) {
          print('⚠️ Update failed for ${t.uuid}: $e');
        }
      }

      // 🌱 STEP 4: Handle unsynced new trees
      final unsynced = await _localDB.fetchUnsyncedTrees();
      print('🌱 Found ${unsynced.length} new unsynced trees');
      for (final tree in unsynced) {
        try {
          // --- resolve speciesId ---
          String resolveSpeciesId(String? s) {
            if (s == null) return '';
            if (int.tryParse(s) != null) return s;
            return s;
          }

          String speciesIdToSend = resolveSpeciesId(tree.speciesId?.toString());

          if (speciesIdToSend.isEmpty || int.tryParse(speciesIdToSend) == null) {
            try {
              final speciesList = await TreeApi.fetchSpecies();
              final match = speciesList.firstWhere(
                (s) =>
                    (s['name'] ?? '').toString().toLowerCase() ==
                    (tree.speciesId ?? '').toString().toLowerCase(),
                orElse: () => <String, dynamic>{},
              );
              if (match.containsKey('id')) {
                speciesIdToSend = match['id'].toString();
              }
            } catch (e) {
              print('⚠️ Could not fetch species list: $e');
            }
          }

          // --- upload ---
          final response = await TreeApi.createTree(
            speciesId: speciesIdToSend,
            plantedAt: tree.plantedAt is String
                ? tree.plantedAt as String
                : (tree.plantedAt == null
                    ? ''
                    : tree.plantedAt.toString()),
            height: tree.height ?? 0.0,
            diameter: tree.diameter ?? 0.0,
            floweringPeriod: tree.floweringPeriod is String
                ? tree.floweringPeriod as String
                : (tree.floweringPeriod ?? '').toString(),
            imageFile: tree.imageFile,
          );

          if (response['success'] == true ||
              response['status'] == 'success' ||
              response.containsKey('data')) {
            // mark as synced
            final updated = await _localDB.markAsSynced(tree.uuid);
            if (updated > 0) {
              print('✅ Synced new tree: ${tree.uuid}');
            } else {
              print('⚠️ markAsSynced updated 0 rows for ${tree.uuid}');
            }
          } else {
            print('⚠️ Server rejected new tree ${tree.uuid}');
          }
        } catch (e) {
          print('⚠️ Create sync failed for ${tree.uuid}: $e');
        }
      }
    } finally {
      _isRunning = false;
      _lastRun = DateTime.now();
      print('🔁 Sync process complete.');
    }
  }
}
