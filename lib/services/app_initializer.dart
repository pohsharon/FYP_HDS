import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/tree_model.dart';
import '../models/fruit_model.dart';
import '../repositories/tree_repository.dart';
import 'api/tree_api.dart';
import 'api/fruit_api.dart';
import 'api/tree_growth_api.dart';
import 'api/health_api.dart';
import 'api/agrochemical_api.dart';
import 'api/disease_api.dart';
// local_db import not required here
import '../models/tree_growth_model.dart';
import '../utils/connectivity_helper.dart';
import '../services/local database/tree_db.dart';
import '../services/local database/fruit_db.dart';
import '../services/local database/growth_db.dart';
import '../services/local database/health_db.dart';
import '../services/local database/agro_db.dart';
import '../models/health_model.dart';
import '../models/agrochemical_model.dart';
import 'sync_services/tree_sync.dart';
import 'sync_services/fruit_sync.dart';
import 'sync_services/health_sync.dart';
import '../services/local database/disease_db.dart';

class AppInitializer {
  // Guard to ensure we only register the connectivity listener once
  static bool _connectivityListenerInitialized = false;
  // When true, the connectivity listener will ignore the first reconnect event.
  // This prevents duplicate caching when `initializeApp()` already performed the initial cache
  // and the listener fires immediately after registration on some platforms.
  static bool _skipFirstReconnect = false;

  static Future<List<TreeModel>> initializeApp() async {
    final online = await ConnectivityHelper.hasInternetConnection();
  // Local DB instance will be fetched where needed
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
        // Fetch and cache disease list for offline use
        try {
          final remoteDiseases = await DiseaseApi.fetchDiseases();
          await DiseaseDB().saveDiseaseList(remoteDiseases);
          print('🦠 Diseases fetched & cached during init (${remoteDiseases.length})');
        } catch (e) {
          print('⚠️ Failed to fetch/cache diseases during init: $e');
        }
  final repo = TreeRepository();
  // Force a fresh remote fetch during initialization
  trees = await repo.getTrees(forceRefresh: true);
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
        // Fetch and cache health records in bulk, then group per-tree before caching
        try {
          final healthDB = HealthDB();
          final allRemoteHealth = await HealthApi.fetchAllHealthRecords();
          print('ℹ️ Fetched ${allRemoteHealth.length} total remote health rows during init');

          // Group by tree_uuid
          final Map<String, List<Map<String, dynamic>>> healthByTree = {};
          for (final h in allRemoteHealth) {
            final tUuid = h['tree_uuid'] ?? h['treeUuid'] ?? '';
            if (tUuid == null || (tUuid is String && tUuid.isEmpty)) continue;
            healthByTree.putIfAbsent(tUuid as String, () => []).add(Map<String, dynamic>.from(h));
          }

          for (final t in trees) {
            try {
              final remoteForTree = healthByTree[t.uuid] ?? [];
              final healthModels = remoteForTree.map((h) => HealthModel.fromMap(h)).toList();
              await healthDB.cacheRemoteHealth(healthModels);
            } catch (e) {
              print('⚠️ Failed to cache health for tree=${t.uuid} during init: $e');
            }
          }
          print('🌱 Health records fetched & cached during init');
        } catch (e) {
          print('⚠️ Failed to fetch/cache health records during init: $e');
        }
        // Fetch and cache agrochemical records in bulk, then group per-tree before caching
        try {
          final agroDB = AgroDB();
          final allRemoteAgro = await AgrochemicalApi.fetchAllAgroRecords();
          print('ℹ️ Fetched ${allRemoteAgro.length} total remote agro rows during init');

          // Group by tree_uuid
          final Map<String, List<Map<String, dynamic>>> agroByTree = {};
          for (final a in allRemoteAgro) {
            final tUuid = a['tree_uuid'] ?? a['treeUuid'] ?? '';
            if (tUuid == null || (tUuid is String && tUuid.isEmpty)) continue;
            agroByTree.putIfAbsent(tUuid as String, () => []).add(Map<String, dynamic>.from(a));
          }

          for (final t in trees) {
            try {
              final remoteForTree = agroByTree[t.uuid] ?? [];
              final agroModels = remoteForTree.map((a) => AgrochemicalModel.fromMap(a)).toList();
              await agroDB.cacheRemoteAgrochemical(agroModels);
            } catch (e) {
              print('⚠️ Failed to cache agrochemical for tree=${t.uuid} during init: $e');
            }
          }
          print('🧪 Agrochemical records fetched & cached during init');
        } catch (e) {
          print('⚠️ Failed to fetch/cache agrochemical records during init: $e');
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

        // Attempt to sync any pending health records created while offline
        try {
          await SyncHealth().syncHealth();
          print('🩺 Health sync attempted during init');
        } catch (e) {
          print('⚠️ Health sync during init failed: $e');
        }
          // We performed the initial full cache during init; skip the first reconnect
          // event in the connectivity listener (if it fires immediately after registration)
          _skipFirstReconnect = true;
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
        // If requested, skip the first reconnect event to avoid duplicating the init cache
        if (_skipFirstReconnect) {
          print('ℹ️ Skipping first reconnect event after init to avoid duplicate caching');
          _skipFirstReconnect = false;
          return;
        }
        print('🌐 Reconnected — syncing...');
        try {
          final treeDB = TreeDB();
          final fruitDB = FruitDB();
          final growthDB = GrowthDB();
          final repo = TreeRepository();
          // On reconnect we want a fresh copy
          final refreshed = await repo.getTrees(forceRefresh: true);
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
                final growthModels = remoteForTree.map((g) => TreeGrowthModel.fromMap(g)).toList();
                await growthDB.cacheRemoteGrowths(growthModels);
              } catch (inner) {
                print('⚠️ Failed to cache growths for a tree after reconnect: $inner');
              }
            }
            // Fetch and cache health records in bulk after reconnect, then group per-tree
            try {
              final healthDB = HealthDB();
              final allRemoteHealth = await HealthApi.fetchAllHealthRecords();
              print('ℹ️ Fetched ${allRemoteHealth.length} total remote health rows after reconnect');

              // Group by tree_uuid
              final Map<String, List<Map<String, dynamic>>> healthByTree = {};
              for (final h in allRemoteHealth) {
                final tUuid = h['tree_uuid'] ?? h['treeUuid'] ?? '';
                if (tUuid == null || (tUuid is String && tUuid.isEmpty)) continue;
                healthByTree.putIfAbsent(tUuid as String, () => []).add(Map<String, dynamic>.from(h));
              }

              for (final t in refreshed) {
                try {
                  final remoteForTree = healthByTree[t.uuid] ?? [];
                  final healthModels = remoteForTree.map((h) => HealthModel.fromMap(h)).toList();
                  await healthDB.cacheRemoteHealth(healthModels);
                } catch (e) {
                  print('⚠️ Failed to cache health for tree=${t.uuid} after reconnect: $e');
                }
              }
              print('🌱 Health records fetched & cached after reconnect');
            } catch (e) {
              print('⚠️ Failed to fetch/cache health records after reconnect: $e');
            }
            // Fetch and cache global diseases list after reconnect
            try {
              final remoteDiseases = await DiseaseApi.fetchDiseases();
              await DiseaseDB().saveDiseaseList(remoteDiseases);
              print('🦠 Diseases fetched & cached after reconnect (${remoteDiseases.length})');
            } catch (e) {
              print('⚠️ Failed to fetch/cache diseases after reconnect: $e');
            }
            // Fetch and cache agrochemical records in bulk after reconnect, then group per-tree
            try {
              final agroDB = AgroDB();
              final allRemoteAgro = await AgrochemicalApi.fetchAllAgroRecords();
              print('ℹ️ Fetched ${allRemoteAgro.length} total remote agro rows after reconnect');

              // Group by tree_uuid
              final Map<String, List<Map<String, dynamic>>> agroByTree = {};
              for (final a in allRemoteAgro) {
                final tUuid = a['tree_uuid'] ?? a['treeUuid'] ?? '';
                if (tUuid == null || (tUuid is String && tUuid.isEmpty)) continue;
                agroByTree.putIfAbsent(tUuid as String, () => []).add(Map<String, dynamic>.from(a));
              }

              for (final t in refreshed) {
                try {
                  final remoteForTree = agroByTree[t.uuid] ?? [];
                  final agroModels = remoteForTree.map((a) => AgrochemicalModel.fromMap(a)).toList();
                  await agroDB.cacheRemoteAgrochemical(agroModels);
                } catch (e) {
                  print('⚠️ Failed to cache agrochemical for tree=${t.uuid} after reconnect: $e');
                }
              }
              print('🧪 Agrochemical records fetched & cached after reconnect');
            } catch (e) {
              print('⚠️ Failed to fetch/cache agrochemical records after reconnect: $e');
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
          // Sync health after fruits
          try {
            await SyncHealth().syncHealth();
            print('🩺 Health sync complete after reconnect');
          } catch (e) {
            print('⚠️ Health sync after reconnect failed: $e');
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
