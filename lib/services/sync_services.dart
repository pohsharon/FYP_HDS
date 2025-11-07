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
          if (t.id == null) {
            print('⚠️ Cannot update remote for ${t.uuid} because id is null');
            continue;
          }
          final resp = await TreeApi.updateTree(
            id: t.id.toString(),
            speciesId: t.speciesId ?? '',
            plantedAt: t.plantedAt?.toIso8601String() ?? '',
            height: t.height ?? 0.0,
            diameter: t.diameter ?? 0.0,
            floweringPeriod: t.floweringPeriod?.toString() ?? '',
            imageFile: t.imageFile,
          );
          if (resp['success'] == true) {
            await _localDB.clearPendingUpdate(t.uuid);
            print('✅ Synced update: ${t.uuid}');
          } else {
            print('⚠️ Server rejected update for ${t.uuid}');
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
