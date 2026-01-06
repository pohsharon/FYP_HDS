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
            await FruitDB().clearFruitPendingUpdate(f.harvest_uuid ?? '');
            print('✅ Synced fruit update ${f.harvest_uuid}');
            continue;
          } catch (e) {
            final msg = e.toString();
            if (msg.contains('404') ||
                msg.contains('Not Found') ||
                msg.contains('No query results')) {
              print(
                'ℹ️ Fruit update returned 404 for ${f.harvest_uuid}; will try to create instead',
              );
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
              await FruitDB().clearFruitPendingUpdate(f.harvest_uuid ?? '');
              print('✅ Created fruit during update fallback ${f.harvest_uuid}');
            } else {
              print(
                '⚠️ Create fallback for fruit ${f.harvest_uuid} returned unexpected response',
              );
            }
          } catch (e) {
            print('❌ Create fallback failed for fruit ${f.harvest_uuid}: $e');
          }
        } catch (e) {
          print(
            '⚠️ Failed to process pending fruit update ${f.harvest_uuid}: $e',
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
            await FruitDB().markFruitAsSynced(fruit.harvest_uuid ?? '');
            print('✅ Synced new fruit ${fruit.harvest_uuid}');
          } else {
            print(
              '⚠️ Fruit create API returned unexpected response for ${fruit.harvest_uuid}: $response',
            );
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
