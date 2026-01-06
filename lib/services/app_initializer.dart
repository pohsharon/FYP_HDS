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
import '../services/local database/harvest_db.dart';
import '../models/health_model.dart';
import '../models/agrochemical_model.dart';
import 'sync_services/tree_sync.dart';
import 'sync_services/fruit_sync.dart';
import 'sync_services/health_sync.dart';
import 'sync_services/agro_sync.dart';
import '../services/local database/disease_db.dart';

class AppInitializer {
  static const bool _logEnabled = false;
  static void _log(String message) {
    if (_logEnabled) print(message);
  }
  // Guard to ensure we only register the connectivity listener once
  static bool _connectivityListenerInitialized = false;
  // Gate to avoid running connectivity-driven syncs before login completes
  static bool _connectivitySyncEnabled = false;
  // When true, the connectivity listener will ignore the first reconnect event.
  // This prevents duplicate caching when `cacheAllData()` already performed the initial cache
  // and the listener fires immediately after registration on some platforms.
  static bool _skipFirstReconnect = false;

  static void enableConnectivitySync() {
    _connectivitySyncEnabled = true;
  }

  /// Cache all data from remote to local storage
  static Future<void> cacheAllData() async {
    final online = await ConnectivityHelper.hasInternetConnection();
    final treeDB = TreeDB();
    final fruitDB = FruitDB();
    final growthDB = GrowthDB();

    final nowStamp = DateTime.now().toIso8601String();
    if (!online) {
      _log('📴 Offline mode detected at $nowStamp');
      return;
    }

    _log('🌐 Online mode detected at $nowStamp');
    try {
      // Fetch species
      try {
        await TreeApi.fetchSpecies();
      } catch (e) {
        _log('❌ Error fetching species: $e');
      }

      // Fetch and cache disease list for offline use
      try {
        final remoteDiseases = await DiseaseApi.fetchDiseases();
        await DiseaseDB().saveDiseaseList(remoteDiseases);
      } catch (e) {
        _log('❌ Error fetching diseases: $e');
      }

      // Fetch and cache agrochemical master list for offline use
      try {
        final agroTypes = await AgrochemicalApi.getAgrochemical();
        await AgroDB().saveAgrochemicalList(agroTypes);
      } catch (e) {
        _log('❌ Error fetching agrochemicals: $e');
      }

      // Fetch and cache trees
      final repo = TreeRepository();
      final trees = await repo.getTrees(forceRefresh: true);
      await treeDB.cacheRemoteTrees(trees);

      // Fetch and cache fruits for offline use
      try {
        final remoteFruits = await FruitApi.fetchFruits();
        final fruitModels = remoteFruits.map((f) => FruitModel.fromMap(f)).toList();
        await fruitDB.cacheRemoteFruits(fruitModels);
      } catch (e) {
          _log('❌ Error fetching fruits: $e');
      }

      // Fetch and cache health records in bulk, then group per-tree before caching
      try {
        final healthDB = HealthDB();
        final allRemoteHealth = await HealthApi.fetchAllHealthRecords();

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
            _log('❌ Error caching health for tree ${t.uuid}: $e');
          }
        }
      } catch (e) {
        _log('❌ Error fetching health records: $e');
      }

      // Fetch and cache agrochemical records in bulk, then group per-tree before caching
      try {
        final agroDB = AgroDB();
        final allRemoteAgro = await AgrochemicalApi.fetchAllAgroRecords();

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
            _log('❌ Error caching agro for tree ${t.uuid}: $e');
          }
        }
      } catch (e) {
        _log('❌ Error fetching agrochemical records: $e');
      }

      // Fetch and cache growth logs once, then group them per-tree before caching
      try {
        final remoteGrowth = await TreeGrowthApi.fetchAllGrowthLogs();
        final growthModels = remoteGrowth.map((g) => TreeGrowthModel.fromMap(g)).toList();
        await growthDB.cacheRemoteGrowths(growthModels);
      } catch (e) {
        _log('❌ Error fetching growth logs: $e');
      }

      // Fetch and cache harvest events for offline use
      try {
        final harvestDB = HarvestDB();
        await harvestDB.fetchAndCacheFromCloud();
      } catch (e) {
        _log('❌ Error fetching harvest events: $e');
      }

      // Sync any unsynced data
      await SyncTrees().syncUnsyncedTrees();

      // Also attempt to sync any fruits that were created offline
      try {
        await SyncFruits().syncFruits();
      } catch (e) {
        _log('❌ Error syncing fruits: $e');
      }

      // Attempt to sync any pending health records created while offline
      try {
        await SyncHealth().syncHealth();
      } catch (e) {
        _log('❌ Error syncing health: $e');
      }

      // Attempt to sync any pending agrochemical records created while offline
      try {
        await SyncAgro().syncAgro();
      } catch (e) {
        _log('❌ Error syncing agrochemicals: $e');
      }

      final timestamp = DateTime.now().toIso8601String();
      _log('✅ Sync complete at $timestamp');

      // We performed the initial full cache; skip the first reconnect
      // event in the connectivity listener (if it fires immediately after registration)
      _skipFirstReconnect = true;
    } catch (e) {
      _log('❌ Error during cache: $e');
    }
  }

  static Future<List<TreeModel>> initializeApp() async {
    final online = await ConnectivityHelper.hasInternetConnection();
  // Local DB instance will be fetched where needed
    final treeDB = TreeDB();
    final fruitDB = FruitDB();
    final growthDB = GrowthDB();
    List<TreeModel> trees = [];

    final nowStamp = DateTime.now().toIso8601String();
    if (!online) {
      _log('📴 Offline mode detected at $nowStamp');
      trees = await treeDB.fetchAllTrees();
    } else {
      _log('🌐 Online mode detected at $nowStamp');
      try {
        try {
          await TreeApi.fetchSpecies();
        } catch (e) {
          _log('❌ Error fetching species: $e');
        }
        // Fetch and cache disease list for offline use
        try {
          final remoteDiseases = await DiseaseApi.fetchDiseases();
          await DiseaseDB().saveDiseaseList(remoteDiseases);
        } catch (e) {
          _log('❌ Error caching diseases: $e');
        }
        // Fetch and cache agrochemical master list for offline use
        try {
          final agroTypes = await AgrochemicalApi.getAgrochemical();
          await AgroDB().saveAgrochemicalList(agroTypes);
        } catch (e) {
          _log('❌ Error caching agrochemicals: $e');
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
        } catch (e) {
          _log('❌ Error caching fruits: $e');
        }
        // Fetch and cache health records in bulk, then group per-tree before caching
        try {
          final healthDB = HealthDB();
          final allRemoteHealth = await HealthApi.fetchAllHealthRecords();

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
              _log('❌ Error caching health for tree ${t.uuid}: $e');
            }
          }
        } catch (e) {
          _log('❌ Error fetching health in init: $e');
        }
        // Fetch and cache agrochemical records in bulk, then group per-tree before caching
        try {
          final agroDB = AgroDB();
          final allRemoteAgro = await AgrochemicalApi.fetchAllAgroRecords();

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
              _log('❌ Error caching agro for tree ${t.uuid}: $e');
            }
          }
        } catch (e) {
          _log('❌ Error fetching agro in init: $e');
        }
        // Fetch and cache growth logs once, then group them per-tree before caching
        try {
          final remoteGrowth = await TreeGrowthApi.fetchAllGrowthLogs();
          final growthModels = remoteGrowth.map((g) => TreeGrowthModel.fromMap(g)).toList();
          await growthDB.cacheRemoteGrowths(growthModels);
        } catch (e) {
          _log('❌ Error caching growth in init: $e');
        }
        await SyncTrees().syncUnsyncedTrees();
        // Also attempt to sync any fruits that were created offline
        try {
          await SyncFruits().syncFruits();
        } catch (e) {
          _log('❌ Error syncing fruits in init: $e');
        }

        // Attempt to sync any pending health records created while offline
        try {
          await SyncHealth().syncHealth();
        } catch (e) {
          _log('❌ Error syncing health in init: $e');
        }
        // Attempt to sync any pending agrochemical records created while offline
        try {
          await SyncAgro().syncAgro();
        } catch (e) {
          _log('❌ Error syncing agro in init: $e');
        }
        // Fetch and cache harvest events for offline use
        try {
          final harvestDB = HarvestDB();
          await harvestDB.fetchAndCacheFromCloud();
        } catch (e) {
          _log('❌ Error caching harvest in init: $e');
        }
          // We performed the initial full cache during init; skip the first reconnect
          // event in the connectivity listener (if it fires immediately after registration)
          _skipFirstReconnect = true;
      } catch (e) {
        _log('❌ Error during init: $e');
        trees = await treeDB.fetchAllTrees();
      }
    }

    return trees;
  }

  static void initConnectivityListener() {
    if (_connectivityListenerInitialized) {
      return;
    }
    _connectivityListenerInitialized = true;
    Connectivity().onConnectivityChanged.listen((status) async {
      if (!_connectivitySyncEnabled) {
        return;
      }
      final online = await ConnectivityHelper.hasInternetConnection();
      if (online) {
        // If requested, skip the first reconnect event to avoid duplicating the init cache
        if (_skipFirstReconnect) {
          _skipFirstReconnect = false;
          return;
        }
        try {
          await cacheAllData();
        } catch (e) {
          _log('❌ Error during reconnect sync: $e');
        }
      }
    });
  }
}
