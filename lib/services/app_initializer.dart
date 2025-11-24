import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/tree_model.dart';
import '../models/fruit_model.dart';
import '../repositories/tree_repository.dart';
import 'api/tree_api.dart';
import 'api/fruit_api.dart';
import '../services/local_db.dart';
import '../services/sync_services.dart';
import '../utils/connectivity_helper.dart';

class AppInitializer {
  static final SyncService _syncService = SyncService();

  static Future<List<TreeModel>> initializeApp() async {
    final online = await ConnectivityHelper.hasInternetConnection();
    final localDB = LocalDB.instance;
    List<TreeModel> trees = [];

    if (!online) {
      print('📴 Offline mode detected. Loading from local DB...');
      trees = await localDB.fetchAllTrees();
    } else {
      print('🌐 Online mode detected. Fetching from remote...');
      try {
        // Fetch species list and cache to local DB for offline name lookups
        try {
          await TreeApi.fetchSpecies();
        } catch (e) {
          print('⚠️ Failed to fetch species during init: $e');
        }
        final repo = TreeRepository();
        trees = await repo.getTrees();
        await localDB.cacheRemoteTrees(trees);
        // Fetch and cache fruits for offline use
        try {
          final remoteFruits = await FruitApi.fetchFruits();
          final fruitModels = remoteFruits.map((f) => FruitModel.fromMap(f)).toList();
          await localDB.cacheRemoteFruits(fruitModels);
          print('🍎 Fruits fetched & cached during init');
        } catch (e) {
          print('⚠️ Failed to fetch/cache fruits during init: $e');
        }
        await _syncService.syncUnsyncedTrees();
        // Also attempt to sync any fruits that were created offline
        try {
          await _syncService.syncFruits();
          print('🍎 Fruit sync complete during init');
        } catch (e) {
          print('⚠️ Fruit sync during init failed: $e');
        }
      } catch (e) {
        print('⚠️ Remote fetch failed: $e');
        trees = await localDB.fetchAllTrees();
      }
    }

    return trees;
  }

  static void initConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((status) async {
      final online = await ConnectivityHelper.hasInternetConnection();
      if (online) {
        print('🌐 Reconnected — syncing...');
        try {
          final localDB = LocalDB.instance;
          final repo = TreeRepository();
          final refreshed = await repo.getTrees();
          await localDB.cacheRemoteTrees(refreshed);
          // Fetch and cache fruits after reconnect
          try {
            final remoteFruits = await FruitApi.fetchFruits();
            final fruitModels = remoteFruits.map((f) => FruitModel.fromMap(f)).toList();
            await localDB.cacheRemoteFruits(fruitModels);
            print('🍎 Fruits fetched & cached after reconnect');
          } catch (e) {
            print('⚠️ Failed to fetch/cache fruits after reconnect: $e');
          }
          await _syncService.syncUnsyncedTrees();
          // Sync fruits after trees
          try {
            await _syncService.syncFruits();
            print('🍎 Fruit sync complete after reconnect');
          } catch (e) {
            print('⚠️ Fruit sync after reconnect failed: $e');
          }
        } catch (e) {
          print('⚠️ Sync error: $e');
        }
      } else {
        print('📴 Offline mode — sync paused');
      }
    });
  }
}
