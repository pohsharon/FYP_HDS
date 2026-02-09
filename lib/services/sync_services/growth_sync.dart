import '../local database/growth_db.dart';
import '../api/tree_growth_api.dart';
import '../app_initializer.dart';
import 'dart:async';

class SyncGrowth {
  Future<void> syncGrowth() async {
    try {
      final db = GrowthDB();
      
      // 1) Handle pending deletes
      final deletes = await db.fetchPendingDeletes();
      for (final g in deletes) {
        if (AppInitializer.isAbortRequested) {
          print('⚠️ Aborting growth sync due to connectivity loss');
          break;
        }
        try {
          final uuid = g['uuid']?.toString() ?? '';
          if (uuid.isEmpty) continue;
          
          // Note: Currently TreeGrowthApi doesn't have deleteGrowthLog method
          // If backend supports deletion, uncomment and implement:
          // await TreeGrowthApi.deleteGrowthLog(uuid);
          
          await db.deleteGrowthByUuid(uuid);
          print('✅ Deleted growth log: $uuid');
        } catch (e) {
          print('⚠️ Failed to delete growth log: $e');
        }
      }
      
      // 2) Handle pending updates
      final updates = await db.fetchPendingUpdates();
      for (final g in updates) {
        if (AppInitializer.isAbortRequested) {
          print('⚠️ Aborting growth sync due to connectivity loss');
          break;
        }
        try {
          final uuid = g['uuid']?.toString() ?? '';
          if (uuid.isEmpty) continue;
          
          // Note: Currently TreeGrowthApi doesn't have updateGrowthLog method
          // If backend supports updates, uncomment and implement:
          // await TreeGrowthApi.updateGrowthLog(
          //   uuid: uuid,
          //   height: g['height'] as double?,
          //   diameter: g['diameter'] as double?,
          // );
          
          await db.markGrowthAsSynced(uuid);
          print('✅ Synced growth log update: $uuid');
        } catch (e) {
          print('⚠️ Failed to sync growth log update: $e');
        }
      }
      
      // 3) Handle unsynced new growth logs
      final unsynced = await db.fetchUnsyncedGrowths();
      for (final g in unsynced) {
        if (AppInitializer.isAbortRequested) {
          print('⚠️ Aborting growth sync due to connectivity loss');
          break;
        }
        try {
          try {
            await TreeGrowthApi.addGrowthLog(
              treeUuid: g.treeUuid,
              height: g.height ?? 0.0,
              diameter: g.diameter ?? 0.0,
            ).timeout(const Duration(seconds: 10));
          } on TimeoutException {
            print('❌ addGrowthLog timed out for ${g.uuid}');
            continue;
          }
          
          // Mark as synced
          await db.markGrowthAsSynced(g.uuid);
        } catch (e) {
          print('⚠️ Failed to sync new growth log: $e');
        }
      }
    } catch (e) {
      print('⚠️ Growth sync error: $e');
    }
  }
}
