import '../local database/tree_db.dart';
import '../local database/agro_db.dart';
import '../local database/health_db.dart';
import '../local database/growth_db.dart';
import '../local database/fruit_db.dart';
import '../api/tree_api.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SyncTrees {
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
      final hasInternet =
          await Connectivity().checkConnectivity() != ConnectivityResult.none;
      if (!hasInternet) {
        print('📴 Offline — sync postponed');
        return;
      }

      // 🧹 STEP 2: Handle pending deletes
      final deletes = await TreeDB().fetchPendingDeletes();
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

            final serverId =
                treeObj['id']?.toString() ?? treeObj['server_id']?.toString();
            if (serverId != null && serverId.isNotEmpty) {
              await TreeApi.deleteTree(serverId);
              await TreeDB().deleteTreeByUuid(t.uuid);
              print(
                '✅ Deleted remote & local by resolved id: ${t.uuid} -> $serverId',
              );
              continue;
            } else {
              print('⚠️ Could not resolve server id for delete for ${t.uuid}');
            }
          } catch (e) {
            final msg = e.toString();
            if (msg.contains('No query results') ||
                msg.contains('NotFoundHttpException') ||
                msg.contains('404') ||
                msg.contains('Not Found')) {
              // Remote already missing — remove local row and consider delete successful
              await TreeDB().deleteTreeByUuid(t.uuid);
              print(
                'ℹ️ Remote not found for uuid ${t.uuid}; removed local row',
              );
              continue;
            } else {
              print(
                '⚠️ Failed to resolve server id for delete for ${t.uuid}: $e',
              );
            }
          }

          // As a fallback, if no uuid-resolve/delete happened, try delete by local numeric id
          if (t.id != null) {
            try {
              await TreeApi.deleteTree(t.id.toString());
              await TreeDB().deleteTreeByUuid(t.uuid);
              print('✅ Deleted remote & local by local id fallback: ${t.uuid}');
            } catch (e) {
              final msg = e.toString();
              if (msg.contains('No query results') ||
                  msg.contains('NotFoundHttpException') ||
                  msg.contains('404') ||
                  msg.contains('Not Found')) {
                await TreeDB().deleteTreeByUuid(t.uuid);
                print(
                  'ℹ️ Remote record not found for id ${t.id}; removed local row ${t.uuid}',
                );
              } else {
                print('⚠️ Delete by id fallback failed for ${t.uuid}: $e');
              }
            }
          } else {
            print(
              '⚠️ Could not delete ${t.uuid}: no server id resolved and no local id available',
            );
          }
        } catch (e) {
          print('⚠️ Error deleting ${t.uuid}: $e');
        }
      }

      // 📝 STEP 3: Handle pending updates
      final updates = await TreeDB().fetchPendingUpdates();
      print('🔄 Found ${updates.length} trees with pending updates');
      for (final t in updates) {
        try {
          // Check if this is a location-only update
          bool isLocationUpdate = (t.latitude != null || t.longitude != null);
          print('📍 Tree ${t.uuid}: isLocationUpdate=$isLocationUpdate, lat=${t.latitude}, lng=${t.longitude}');
          
          // If it's a location update, use the dedicated location API endpoint
          if (isLocationUpdate && t.latitude != null && t.longitude != null) {
            try {
              print('🌐 Syncing location for tree ${t.uuid}...');
              await TreeApi.addTreeLocation(
                treeUuid: t.uuid,
                latitude: t.latitude!,
                longitude: t.longitude!,
              );
              await TreeDB().clearPendingUpdate(t.uuid);
              print('✅ Synced location update: ${t.uuid}');
              continue;
            } catch (e) {
              print('⚠️ Location update failed for ${t.uuid}: $e');
              // Don't fall through to general update for location-only changes
              // Just skip and try again on next sync
              continue;
            }
          }
          
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
                await TreeDB().clearPendingUpdate(t.uuid);
                print('✅ Synced update by id: ${t.uuid}');
                updated = true;
              } else {
                print('⚠️ Server rejected update by id for ${t.uuid}');
              }
            } catch (e) {
              print('⚠️ Update by id failed for ${t.uuid}: $e');
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

              final serverId =
                  treeObj['id']?.toString() ?? treeObj['server_id']?.toString();
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
                  await TreeDB().clearPendingUpdate(t.uuid);
                  print(
                    '✅ Synced update by resolved server id: ${t.uuid} -> $serverId',
                  );
                  updated = true;
                } else {
                  print(
                    '⚠️ Server rejected update for resolved id $serverId for ${t.uuid}',
                  );
                }
              } else {
                print('⚠️ Could not resolve server id for uuid ${t.uuid}');
              }
            } catch (e) {
              final msg = e.toString();
              if (msg.contains('No query results') ||
                  msg.contains('NotFoundHttpException') ||
                  msg.contains('404') ||
                  msg.contains('MethodNotAllowedHttpException')) {
                print(
                  'ℹ️ Could not resolve server id or update for ${t.uuid}: ${msg.split("\n").first}',
                );
              } else {
                print(
                  '⚠️ Failed to resolve server id/update for ${t.uuid}: $e',
                );
              }
            }
          }

          if (!updated) {
            print(
              '⚠️ Update failed for ${t.uuid}: unable to sync by id or uuid',
            );
          }
        } catch (e) {
          print('⚠️ Update failed for ${t.uuid}: $e');
        }
      }

      // 🌱 STEP 4: Handle unsynced new trees
      final unsynced = await TreeDB().fetchUnsyncedTrees();
      for (final tree in unsynced) {
        try {
          // --- resolve speciesId ---
          String resolveSpeciesId(String? s) {
            if (s == null) return '';
            if (int.tryParse(s) != null) return s;
            return s;
          }

          String speciesIdToSend = resolveSpeciesId(tree.speciesId?.toString());

          if (speciesIdToSend.isEmpty ||
              int.tryParse(speciesIdToSend) == null) {
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
            plantedAt:
                tree.plantedAt is String
                    ? tree.plantedAt as String
                    : (tree.plantedAt == null ? '' : tree.plantedAt.toString()),
            height: tree.height ?? 0.0,
            diameter: tree.diameter ?? 0.0,
            floweringPeriod:
                tree.floweringPeriod is String
                    ? tree.floweringPeriod as String
                    : (tree.floweringPeriod ?? '').toString(),
            imageFile: tree.imageFile,
          );

          if (response['success'] == true ||
              response['status'] == 'success' ||
              response.containsKey('data')) {
            // mark as synced
            final updated = await TreeDB().markAsSynced(tree.uuid);
            if (updated == 0) {
              print('⚠️ markAsSynced updated 0 rows for ${tree.uuid}');
            }

            // If the server returned an authoritative UUID different from the
            // local one, update local rows so child records reference the
            // server UUID before child sync runs. Response shape may vary
            // so handle common keys.
            try {
              Map<String, dynamic> serverObj = {};
              if (response.containsKey('data') && response['data'] is Map) {
                serverObj = Map<String, dynamic>.from(response['data']);
              } else {
                serverObj = Map<String, dynamic>.from(response);
              }

              final serverUuid =
                  (serverObj['uuid'] ??
                          serverObj['id'] ??
                          serverObj['server_id'])
                      ?.toString();
              if (serverUuid != null &&
                  serverUuid.isNotEmpty &&
                  serverUuid != tree.uuid) {
                // Update trees table uuid
                await TreeDB().reassignUuid(tree.uuid, serverUuid);

                // Remap child records to point to serverUuid
                try {
                  await AgroDB().reassignTreeUuid(tree.uuid, serverUuid);
                  await HealthDB().reassignTreeUuid(tree.uuid, serverUuid);
                  await GrowthDB().reassignTreeUuid(tree.uuid, serverUuid);
                  await FruitDB().reassignTreeUuid(tree.uuid, serverUuid);
                } catch (childErr) {
                  print(
                    '⚠️ Failed to remap child records for ${tree.uuid} -> $serverUuid: $childErr',
                  );
                }
                // If the server provided an authoritative tree_tag, persist it locally
                try {
                  final serverTag =
                      (serverObj['tree_tag'] ??
                              serverObj['treeTag'] ??
                              serverObj['tag'])
                          ?.toString();
                  if (serverTag != null && serverTag.isNotEmpty) {
                    await TreeDB().updateTreeByUuid(serverUuid, {
                      'tree_tag': serverTag,
                    }, markPendingUpdate: false);
                  }
                } catch (e) {
                  print('❌ Error updating tree_tag: $e');
                }
              }
            } catch (e) {
              print('⚠️ Failed to extract server uuid after tree create: $e');
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
    }
  }
}
