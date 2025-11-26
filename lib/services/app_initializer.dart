import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/tree_model.dart';
import '../models/fruit_model.dart';
import '../repositories/tree_repository.dart';
import 'api/tree_api.dart';
import 'api/fruit_api.dart';
import 'api/tree_growth_api.dart';
import 'api/health_api.dart';
import 'local database/local_db.dart';
import '../models/tree_growth_model.dart';
import 'sync_services/sync_services.dart';
import '../utils/connectivity_helper.dart';
import '../services/local database/tree_db.dart';
import '../services/local database/fruit_db.dart';
import '../services/local database/growth_db.dart';
import '../services/local database/health_db.dart';
import '../models/health_model.dart';
import 'sync_services/tree_sync.dart';
import 'sync_services/fruit_sync.dart';

class AppInitializer {
  static final SyncService _syncService = SyncService();
  // Guard to ensure we only register the connectivity listener once
  static bool _connectivityListenerInitialized = false;

  static Future<List<TreeModel>> initializeApp() async {
    final online = await ConnectivityHelper.hasInternetConnection();
    final localDB = LocalDB.instance;
    final treeDB = TreeDB();
    final fruitDB = FruitDB();
    final growthDB = GrowthDB();
    List<TreeModel> trees = [];

    if (!online) {
      print('📴 Offline mode detected. Loading from local DB...');
      trees = await treeDB.fetchAllTrees();
    } else {
      print('🌐 Online mode detected. Fetching from remote...');
      try {
        try {
          await TreeApi.fetchSpecies();
        } catch (e) {
          print('⚠️ Failed to fetch species during init: $e');
        }
        final repo = TreeRepository();
        trees = await repo.getTrees();
        await treeDB.cacheRemoteTrees(trees);
        // Fetch and cache fruits for offline use
        try {
          final remoteFruits = await FruitApi.fetchFruits();
          final fruitModels = remoteFruits.map((f) => FruitModel.fromMap(f)).toList();
          await fruitDB.cacheRemoteFruits(fruitModels);
          print('🍎 Fruits fetched & cached during init');
        } catch (e) {
          print('⚠️ Failed to fetch/cache fruits during init: $e');
        }
        // Fetch and cache health records per tree
        try {
          final healthDB = HealthDB();
          for (final t in trees) {
            try {
              final remoteHealth = await HealthApi.fetchTreeHealthRecords(t.uuid);
              final healthModels = remoteHealth.map((h) => HealthModel.fromMap(h)).toList();
              await healthDB.cacheRemoteHealth(healthModels);
            } catch (e) {
              // per-tree failure should not stop init
              print('⚠️ Failed to fetch/cache health for tree=${t.uuid} during init: $e');
            }
          }
          print('🌱 Health records fetched & cached during init');
        } catch (e) {
          print('⚠️ Failed to fetch/cache health records during init: $e');
        }
        // Fetch and cache growth logs once, then group them per-tree before caching
        try {
          final remoteGrowth = await TreeGrowthApi.fetchAllGrowthLogs();
          final growthModels = remoteGrowth.map((g) => TreeGrowthModel.fromMap(g)).toList();
          await growthDB.cacheRemoteGrowths(growthModels);
          print('🌱 Growth logs fetched & cached during init');
        } catch (e) {
          print('⚠️ Failed to fetch/cache growth logs during init: $e');
        }
        await SyncTrees().syncUnsyncedTrees();
        // Also attempt to sync any fruits that were created offline
        try {
          await SyncFruits().syncFruits();
          print('🍎 Fruit sync complete during init');
        } catch (e) {
          print('⚠️ Fruit sync during init failed: $e');
        }
      } catch (e) {
        print('⚠️ Remote fetch failed: $e');
        trees = await treeDB.fetchAllTrees();
      }
    }

    return trees;
  }

  static void initConnectivityListener() {
    if (_connectivityListenerInitialized) {
      print('⚠️ Connectivity listener already initialized — skipping duplicate registration');
      return;
    }
    _connectivityListenerInitialized = true;
    print('ℹ️ Registering connectivity listener');
    Connectivity().onConnectivityChanged.listen((status) async {
      final online = await ConnectivityHelper.hasInternetConnection();
      if (online) {
        print('🌐 Reconnected — syncing...');
        try {
          final localDB = LocalDB.instance;
          final treeDB = TreeDB();
          final fruitDB = FruitDB();
          final growthDB = GrowthDB();
          final repo = TreeRepository();
          final refreshed = await repo.getTrees();
          await treeDB.cacheRemoteTrees(refreshed);
          // Fetch and cache fruits after reconnect
          try {
            final remoteFruits = await FruitApi.fetchFruits();
            final fruitModels = remoteFruits.map((f) => FruitModel.fromMap(f)).toList();
            await fruitDB.cacheRemoteFruits(fruitModels);
            print('🍎 Fruits fetched & cached after reconnect');
          } catch (e) {
            print('⚠️ Failed to fetch/cache fruits after reconnect: $e');
          }
          // Fetch and cache growth logs once after reconnect, then group per tree
          try {
            final remoteGrowths = await TreeGrowthApi.fetchAllGrowthLogs();
            print('ℹ️ Fetched ${remoteGrowths.length} remote growth rows total after reconnect');

            // Group by tree UUID
            final Map<String, List<Map<String, dynamic>>> growthsByTree = {};
            for (final g in remoteGrowths) {
              final tUuid = g['tree_uuid'] ?? g['treeUuid'] ?? '';
              if (tUuid == null || (tUuid is String && tUuid.isEmpty)) continue;
              growthsByTree.putIfAbsent(tUuid as String, () => []).add(Map<String, dynamic>.from(g));
            }

            for (final t in refreshed) {
              try {
                final treeUuid = t.uuid;
                final remoteForTree = growthsByTree[treeUuid] ?? [];
                print('ℹ️ Fetched ${remoteForTree.length} remote growth rows for tree=$treeUuid after reconnect');
                final growthModels = remoteForTree.map((g) => TreeGrowthModel.fromMap(g)).toList();
                await growthDB.cacheRemoteGrowths(growthModels);
                final cached = await growthDB.fetchAllGrowths(treeUuid: treeUuid);
                print('✅ After caching (reconnect), local growth rows for tree=$treeUuid: ${cached.length}');
              } catch (inner) {
                print('⚠️ Failed to cache growths for a tree after reconnect: $inner');
              }
            }
            // Fetch and cache health records per-tree after reconnect
            try {
              final healthDB = HealthDB();
              for (final t in refreshed) {
                try {
                  final remoteHealth = await HealthApi.fetchTreeHealthRecords(t.uuid);
                  final healthModels = remoteHealth.map((h) => HealthModel.fromMap(h)).toList();
                  await healthDB.cacheRemoteHealth(healthModels);
                  // Optionally check counts (not implemented in HealthDB)
                } catch (e) {
                  print('⚠️ Failed to fetch/cache health for tree=${t.uuid} after reconnect: $e');
                }
              }
              print('🌱 Health records fetched & cached after reconnect');
            } catch (e) {
              print('⚠️ Failed to fetch/cache health records after reconnect: $e');
            }
            print('🌱 Growth logs fetched & cached after reconnect');
          } catch (e) {
            print('⚠️ Failed to fetch/cache growth logs after reconnect: $e');
          }
          await SyncTrees().syncUnsyncedTrees();
          // Sync fruits after trees
          try {
            await SyncFruits().syncFruits();
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
