import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/tree_model.dart';
import '../repositories/tree_repository.dart';
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
        final repo = TreeRepository();
        trees = await repo.getTrees();
        await localDB.cacheRemoteTrees(trees);
        await _syncService.syncUnsyncedTrees();
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
          await _syncService.syncUnsyncedTrees();
        } catch (e) {
          print('⚠️ Sync error: $e');
        }
      } else {
        print('📴 Offline mode — sync paused');
      }
    });
  }
}
