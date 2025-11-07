import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_db.dart';
import 'api/tree_api.dart';

class SyncService {
  final LocalDB _localDB = LocalDB.instance;
  bool _isRunning = false;
  DateTime? _lastRun;

  bool get isRunning => _isRunning;

  Future<void> syncUnsyncedTrees() async {
    // Simple debounce: ignore if we ran very recently
    final now = DateTime.now();
    if (_lastRun != null && now.difference(_lastRun!).inMilliseconds < 1200) {
      print('⏱️ Sync called too soon after last run — skipping');
      return;
    }
    if (_isRunning) {
      print('🔁 Sync already in progress — skipping duplicate call');
      return;
    }
    _isRunning = true;
    _lastRun = now;

    try {
    final connectivityResult = await Connectivity().checkConnectivity();

    // 🔌 Step 1: Only sync if online
    if (connectivityResult == ConnectivityResult.none) {
      print('🔌 Offline — sync postponed');
      return;
    }

    // 🌱 Step 2: Get unsynced trees from local DB
    final unsynced = await _localDB.fetchUnsyncedTrees();
    print('🌱 Found ${unsynced.length} unsynced trees');

    // 🚀 Step 3: Upload each unsynced tree to Supabase / Laravel
    for (final tree in unsynced) {
      try {
        // Resolve speciesId: sometimes local data stores species name instead of id.
        String resolveSpeciesId(String? s) {
          if (s == null) return '';
          // already numeric
          if (int.tryParse(s) != null) return s;
          // maybe of form '{"id":1,"name":"..."}' or just a name; return as-is for now
          return s;
        }

        String speciesIdToSend = resolveSpeciesId(tree.speciesId?.toString());

        // If speciesIdToSend is not numeric, try to fetch species list and match by name
        if (speciesIdToSend.isEmpty || int.tryParse(speciesIdToSend) == null) {
          final checkAgain = await Connectivity().checkConnectivity();
          if (checkAgain != ConnectivityResult.none) {
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
          } else {
            print('🕸️ Still offline — skipping species fetch');
          }
        }

        // ✅ Match parameters exactly with TreeApi.createTree()
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
                  : (tree.floweringPeriod == null
                      ? ''
                      : tree.floweringPeriod.toString()),
          imageFile: tree.imageFile, // optional
        );

        if (response['success'] == true ||
            response['status'] == 'success' ||
            response.containsKey('data')) {
          // 🗂 Step 4: Mark as synced in local DB (try uuid first, then fallback to tree_tag)
          try {
            final updated = await _localDB.markAsSynced(tree.uuid);
            if (updated == 0 && (tree.treeTag != null && tree.treeTag!.isNotEmpty)) {
              final byTag = await _localDB.markAsSyncedByTag(tree.treeTag!);
              if (byTag > 0) {
                print('✅ Synced tree by tag: ${tree.treeTag}');
              } else {
                print('⚠️ markAsSynced updated 0 rows for uuid:${tree.uuid} and tag:${tree.treeTag}');
              }
            } else if (updated > 0) {
              print('✅ Synced tree: ${tree.treeTag ?? tree.uuid}');
            } else {
              print('⚠️ markAsSynced called with empty uuid and no tree_tag provided');
            }
          } catch (e) {
            print('⚠️ Error while marking as synced: $e');
          }
        } else {
          print('⚠️ Server rejected ${tree.uuid}: ${response['message']}');
        }
      } catch (e) {
        print('⚠️ Sync failed for ${tree.uuid}: $e');
      }
    }

    } finally {
      _isRunning = false;
      _lastRun = DateTime.now();
    }

    print('🔁 Sync process complete.');
  }
}
