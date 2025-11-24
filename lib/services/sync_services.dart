import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_db.dart';
import 'api/tree_api.dart';
import 'api/fruit_api.dart';

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
          // Prefer resolving the authoritative server id by UUID first to avoid using
          // stale local numeric ids. If GET by uuid returns 404, treat as already deleted.
          try {
            final remote = await TreeApi.getTreeByUuid(t.uuid);
            Map<String, dynamic> treeObj = {};
            if (remote.containsKey('data') && remote['data'] is Map) {
              treeObj = Map<String, dynamic>.from(remote['data']);
            } else {
              treeObj = Map<String, dynamic>.from(remote);
            }

            final serverId = treeObj['id']?.toString() ?? treeObj['server_id']?.toString();
            if (serverId != null && serverId.isNotEmpty) {
              await TreeApi.deleteTree(serverId);
              await _localDB.deleteTreeByUuid(t.uuid);
              print('✅ Deleted remote & local by resolved id: ${t.uuid} -> $serverId');
              continue;
            } else {
              print('⚠️ Could not resolve server id for delete for ${t.uuid}');
            }
          } catch (e) {
            final msg = e.toString();
            if (msg.contains('No query results') || msg.contains('NotFoundHttpException') || msg.contains('404') || msg.contains('Not Found')) {
              // Remote already missing — remove local row and consider delete successful
              await _localDB.deleteTreeByUuid(t.uuid);
              print('ℹ️ Remote not found for uuid ${t.uuid}; removed local row');
              continue;
            } else {
              print('⚠️ Failed to resolve server id for delete for ${t.uuid}: $e');
            }
          }

          // As a fallback, if no uuid-resolve/delete happened, try delete by local numeric id
          if (t.id != null) {
            try {
              await TreeApi.deleteTree(t.id.toString());
              await _localDB.deleteTreeByUuid(t.uuid);
              print('✅ Deleted remote & local by local id fallback: ${t.uuid}');
            } catch (e) {
              final msg = e.toString();
              if (msg.contains('No query results') || msg.contains('NotFoundHttpException') || msg.contains('404') || msg.contains('Not Found')) {
                await _localDB.deleteTreeByUuid(t.uuid);
                print('ℹ️ Remote record not found for id ${t.id}; removed local row ${t.uuid}');
              } else {
                print('⚠️ Delete by id fallback failed for ${t.uuid}: $e');
              }
            }
          } else {
            print('⚠️ Could not delete ${t.uuid}: no server id resolved and no local id available');
          }
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

  Future<void> syncFruits() async {
    // Full fruit sync: deletes -> updates -> new creations
    try {
      final hasInternet = await Connectivity().checkConnectivity() != ConnectivityResult.none;
      if (!hasInternet) {
        print('📴 Offline — fruit sync postponed');
        return;
      }

      // 1) Pending deletes
      final deletes = await _localDB.fetchPendingFruitDeletes();
      print('🗑️ Found ${deletes.length} pending fruit deletes');
      for (final f in deletes) {
        try {
          try {
            await FruitApi.deleteFruit(f.harvest_uuid ?? '');
            await _localDB.deleteFruitByHarvestUuid(f.harvest_uuid ?? '');
            print('✅ Deleted remote & local fruit ${f.harvest_uuid}');
          } catch (e) {
            final msg = e.toString();
            if (msg.contains('404') || msg.contains('Not Found') || msg.contains('No query results')) {
              // treat as already deleted
              await _localDB.deleteFruitByHarvestUuid(f.harvest_uuid ?? '');
              print('ℹ️ Remote fruit not found ${f.harvest_uuid}; removed local row');
            } else {
              print('⚠️ Failed to delete remote fruit ${f.harvest_uuid}: $e');
            }
          }
        } catch (e) {
          print('⚠️ Error during fruit delete for ${f.harvest_uuid}: $e');
        }
      }

      // 2) Pending updates
      final updates = await _localDB.fetchPendingFruitUpdates();
      print('🔁 Found ${updates.length} pending fruit updates');
      for (final f in updates) {
        try {
          try {
            await FruitApi.updateFruit(
              uuid: f.harvest_uuid ?? '',
              tree_uuid: f.tree_uuid ?? '',
              harvest_uuid: f.harvest_uuid ?? '',
              weight: f.weight ?? 0.0,
              grade: f.grade ?? '',
              harvested_at: f.harvested_at ?? '',
              is_spoiled: f.is_spoiled,
            );
            await _localDB.clearFruitPendingUpdate(f.harvest_uuid ?? '');
            print('✅ Synced fruit update ${f.harvest_uuid}');
            continue;
          } catch (e) {
            final msg = e.toString();
            if (msg.contains('404') || msg.contains('Not Found') || msg.contains('No query results')) {
              print('ℹ️ Fruit update returned 404 for ${f.harvest_uuid}; will try to create instead');
              // fallthrough to create
            } else {
              print('⚠️ Fruit update failed for ${f.harvest_uuid}: $e');
              continue;
            }
          }

          // If update wasn't possible, try creating as a fallback
          try {
            final resp = await FruitApi.createFruit(
              tree_uuid: f.tree_uuid ?? '',
              harvest_uuid: f.harvest_uuid ?? '',
              weight: f.weight ?? 0.0,
              grade: f.grade ?? '',
              harvested_at: f.harvested_at ?? '',
              is_spoiled: f.is_spoiled,
            );
            if (resp['success'] == true || resp.containsKey('data')) {
              await _localDB.clearFruitPendingUpdate(f.harvest_uuid ?? '');
              print('✅ Created fruit during update fallback ${f.harvest_uuid}');
            } else {
              print('⚠️ Create fallback for fruit ${f.harvest_uuid} returned unexpected response');
            }
          } catch (e) {
            print('❌ Create fallback failed for fruit ${f.harvest_uuid}: $e');
          }
        } catch (e) {
          print('⚠️ Failed to process pending fruit update ${f.harvest_uuid}: $e');
        }
      }

      // 3) New unsynced fruits (skip ones marked pending_update or pending_delete)
      final unsynced = await _localDB.getUnsyncedFruits();
      final newOnes = unsynced.where((f) => f.pendingUpdate == 0 && f.pendingDelete == 0).toList();
      print('� Found ${newOnes.length} new unsynced fruits');
      for (final fruit in newOnes) {
        try {
          final payload = {
            'tree_uuid': fruit.tree_uuid ?? '',
            'harvest_uuid': fruit.harvest_uuid ?? '',
            'weight': fruit.weight ?? 0.0,
            'grade': fruit.grade ?? '',
            'harvested_at': fruit.harvested_at ?? '',
            'is_spoiled': fruit.is_spoiled,
          };
          print('🔁 Uploading fruit ${fruit.harvest_uuid} payload=$payload');

          final response = await FruitApi.createFruit(
            tree_uuid: fruit.tree_uuid ?? '',
            harvest_uuid: fruit.harvest_uuid ?? '',
            weight: fruit.weight ?? 0.0,
            grade: fruit.grade ?? '',
            harvested_at: fruit.harvested_at ?? '',
            is_spoiled: fruit.is_spoiled,
          );

          print('📡 Server response for ${fruit.harvest_uuid}: $response');

          if (response['success'] == true || response.containsKey('data')) {
            await _localDB.markFruitAsSynced(fruit.harvest_uuid ?? '');
            print('✅ Synced new fruit ${fruit.harvest_uuid}');
          } else {
            print('⚠️ Fruit create API returned unexpected response for ${fruit.harvest_uuid}: $response');
          }
        } catch (e, st) {
          print('❌ Failed to sync fruit ${fruit.harvest_uuid}: $e');
          print(st);
        }
      }
    } catch (e) {
      print('⚠️ syncFruits failed: $e');
    }
}


  
}
