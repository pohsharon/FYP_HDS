import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_db.dart';
import '../models/tree_model.dart';
import 'api/tree_api.dart';

class SyncService {
  final LocalDB _localDB = LocalDB.instance;

  Future<void> syncUnsyncedTrees() async {
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
          try {
            final speciesList = await TreeApi.fetchSpecies();
            final match = speciesList.firstWhere(
                (s) => (s['name'] ?? '').toString().toLowerCase() == (tree.speciesId ?? '').toString().toLowerCase(),
                orElse: () => Map<String, dynamic>());
            if (match.containsKey('id')) {
              speciesIdToSend = match['id'].toString();
            }
          } catch (_) {
            // ignore and proceed — server will validate and return helpful error
          }
        }

        // ✅ Match parameters exactly with TreeApi.createTree()
        final response = await TreeApi.createTree(
          speciesId: speciesIdToSend,
          plantedAt: tree.plantedAt is String
              ? tree.plantedAt as String
              : (tree.plantedAt == null ? '' : tree.plantedAt.toString()),
          height: tree.height ?? 0.0,
          diameter: tree.diameter ?? 0.0,
          floweringPeriod: tree.floweringPeriod is String
              ? tree.floweringPeriod as String
              : (tree.floweringPeriod == null ? '' : tree.floweringPeriod.toString()),
          imageFile: tree.imageFile, // optional
        );

        if (response['success'] == true ||
            response['status'] == 'success' ||
            response.containsKey('data')) {
          // 🗂 Step 4: Mark as synced in local DB
          await _localDB.markAsSynced(tree.uuid);
          print('✅ Synced tree: ${tree.treeTag ?? tree.uuid}');
        } else {
          print('⚠️ Server rejected ${tree.uuid}: ${response['message']}');
        }
      } catch (e) {
        print('⚠️ Sync failed for ${tree.uuid}: $e');
      }
    }

    print('🔁 Sync process complete.');
  }
}
