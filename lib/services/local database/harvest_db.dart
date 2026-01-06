import 'package:fyp_hbs/services/local database/local_db.dart';
import 'package:fyp_hbs/services/api/tree_api.dart';

class HarvestDB {
  /// Cache a list of remote harvest event maps into the local `harvest_events` table.
  /// This will replace existing rows with the remote set.
  Future<void> cacheRemoteHarvestEvents(List<Map<String, dynamic>> remoteEvents) async {
    final db = await LocalDB.getDatabase();

    try {
      // Replace existing remote cache (we keep this simple for now)
      await db.transaction((txn) async {
        await txn.delete('harvest_events');

        for (final ev in remoteEvents) {
          // Normalize keys
          final String uuid = (ev['uuid'] ?? ev['id'] ?? ev['harvest_uuid'] ?? '').toString();
          final String name = (ev['event_name'] ?? ev['name'] ?? ev['title'] ?? '').toString();
          final String start = (ev['start_date'] ?? ev['begin_date'] ?? ev['created_at'] ?? '').toString();
          final String end = (ev['end_date'] ?? ev['finish_date'] ?? ev['harvested_at'] ?? '').toString();

          final insertMap = {
            'uuid': uuid,
            'event_name': name,
            'start_date': start,
            'end_date': end,
          };

          await txn.insert('harvest_events', insertMap);
        }
      });
    } catch (e) {
      print('⚠️ HarvestDB.cacheRemoteHarvestEvents failed: $e');
      rethrow;
    }
  }

  /// Fetch harvest events from the cloud and cache them locally.
  Future<void> fetchAndCacheFromCloud() async {
    try {
      final remote = await TreeApi.fetchEvents();
      if (remote.isNotEmpty) {
        await cacheRemoteHarvestEvents(remote);
      }
    } catch (_) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllHarvestEvents() async {
    final db = await LocalDB.getDatabase();
    final result = await db.query('harvest_events', orderBy: 'start_date DESC');
    return result.map((r) => Map<String, dynamic>.from(r)).toList();
  }
}
