import '../local database/fruit_db.dart';
import '../api/fruit_api.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SyncFruits {
  Future<void> syncFruits() async {
    try {
      final hasInternet =
          await Connectivity().checkConnectivity() != ConnectivityResult.none;
      if (!hasInternet) {
        print('📴 Offline — fruit sync postponed');
        return;
      }

      // 1) Pending deletes
      final deletes = await FruitDB().fetchPendingFruitDeletes();
      for (final f in deletes) {
        try {
          try {
            await FruitApi.deleteFruit(f.harvest_uuid ?? '');
            await FruitDB().deleteFruitByHarvestUuid(f.harvest_uuid ?? '');
            print('✅ Deleted remote & local fruit ${f.harvest_uuid}');
          } catch (e) {
            final msg = e.toString();
            if (msg.contains('404') ||
                msg.contains('Not Found') ||
                msg.contains('No query results')) {
              // treat as already deleted
              await FruitDB().deleteFruitByHarvestUuid(f.harvest_uuid ?? '');
              print(
                'ℹ️ Remote fruit not found ${f.harvest_uuid}; removed local row',
              );
            } else {
              print('⚠️ Failed to delete remote fruit ${f.harvest_uuid}: $e');
            }
          }
        } catch (e) {
          print('⚠️ Error during fruit delete for ${f.harvest_uuid}: $e');
        }
      }

      // 2) Pending updates
      final updates = await FruitDB().fetchPendingFruitUpdates();
      for (final f in updates) {
        try {
          // Check if this fruit has an offline-generated UUID (gen_*)
          final isOfflineUuid = (f.uuid ?? '').toString().startsWith('gen_');
          
          if (isOfflineUuid) {
            // For offline-created fruits, skip update and go straight to create
            print('📝 Fruit ${f.uuid} is offline-created (gen_*), creating instead of updating...');
          } else {
            // For server-synced fruits, try update first
            try {
              await FruitApi.updateFruit(
                uuid: f.uuid ?? '',
                tree_uuid: f.tree_uuid ?? '',
                harvest_uuid: f.harvest_uuid ?? '',
                weight: f.weight ?? 0.0,
                grade: f.grade ?? '',
                harvested_at: f.harvested_at ?? '',
                is_spoiled: f.is_spoiled,
              );
              await FruitDB().clearFruitPendingUpdate(f.harvest_uuid ?? '');
              print('✅ Synced fruit update ${f.uuid}');
              continue;
            } catch (e) {
              final msg = e.toString();
              if (msg.contains('404') ||
                  msg.contains('Not Found') ||
                  msg.contains('No query results')) {
                print(
                  'ℹ️ Fruit update returned 404 for ${f.uuid}; will try to create instead',
                );
                // fallthrough to create
              } else {
                print('⚠️ Fruit update failed for ${f.uuid}: $e');
                continue;
              }
            }
          }

          // If update wasn't possible, try creating as a fallback (or for offline fruits)
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
              // If this was an offline fruit and server returned a real UUID, update local record
              if (isOfflineUuid) {
                try {
                  final serverData = resp['data'] is Map ? resp['data'] : resp;
                  final serverFruitUuid = serverData['uuid'] ?? serverData['id'];
                  if (serverFruitUuid != null && serverFruitUuid.toString().isNotEmpty) {
                    print('🔄 Reassigning offline fruit UUID ${f.uuid} → $serverFruitUuid');
                    // Update only the uuid field (fruit's ID), keep harvest_uuid unchanged
                    await FruitDB().updateFruitUuid(f.harvest_uuid ?? '', serverFruitUuid.toString());
                  }
                } catch (reassignErr) {
                  print('⚠️ Failed to reassign fruit UUID: $reassignErr');
                }
              }
              await FruitDB().clearFruitPendingUpdate(f.harvest_uuid ?? '');
              print('✅ Created fruit during update fallback ${f.uuid}');
            } else {
              print(
                '⚠️ Create fallback for fruit ${f.uuid} returned unexpected response',
              );
            }
          } catch (e) {
            print('❌ Create fallback failed for fruit ${f.uuid}: $e');
          }
        } catch (e) {
          print(
            '⚠️ Failed to process pending fruit update ${f.uuid}: $e',
          );
        }
      }

      // 3) New unsynced fruits (skip ones marked pending_update or pending_delete)
      final unsynced = await FruitDB().getUnsyncedFruits();
      final newOnes =
          unsynced
              .where((f) => f.pendingUpdate == 0 && f.pendingDelete == 0)
              .toList();
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
          print('🔁 Uploading fruit ${fruit.uuid} payload=$payload');

          final response = await FruitApi.createFruit(
            tree_uuid: fruit.tree_uuid ?? '',
            harvest_uuid: fruit.harvest_uuid ?? '',
            weight: fruit.weight ?? 0.0,
            grade: fruit.grade ?? '',
            harvested_at: fruit.harvested_at ?? '',
            is_spoiled: fruit.is_spoiled,
          );

          print('📡 Server response for ${fruit.uuid}: $response');

          if (response['success'] == true || response.containsKey('data')) {
            // Extract server fruit UUID from response and store it locally
            try {
              final serverData = response['data'] is Map ? response['data'] : response;
              final serverFruitUuid = serverData['uuid'] ?? serverData['id'];
              if (serverFruitUuid != null && serverFruitUuid.toString().isNotEmpty) {
                final updated = await FruitDB().updateFruitUuid(fruit.harvest_uuid ?? '', serverFruitUuid.toString());
                print('💾 Database update returned: $updated rows affected');
                print('✅ Stored server fruit UUID ${fruit.uuid} → $serverFruitUuid');
              }
            } catch (e) {
              print('⚠️ Could not extract server UUID from response: $e');
            }
            
            await FruitDB().markFruitAsSynced(fruit.harvest_uuid ?? '');
            print('✅ Synced new fruit ${fruit.uuid}');
          } else {
            print(
              '⚠️ Fruit create API returned unexpected response for ${fruit.uuid}: $response',
            );
          }
        } catch (e, st) {
          print('❌ Failed to sync fruit ${fruit.uuid}: $e');
          print(st);
        }
      }
    } catch (e) {
      print('⚠️ syncFruits failed: $e');
    }
  }
}
