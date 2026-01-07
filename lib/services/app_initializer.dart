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
import 'sync_services/disease_sync.dart';
import 'sync_services/growth_sync.dart';
import '../services/local database/disease_db.dart';
import 'package:flutter/foundation.dart';

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
  // Track last known online state to only trigger sync on offline -> online transitions
  static bool _wasOnline = false;
  // Prevent overlapping syncs when connectivity flaps quickly
  static bool _isSyncing = false;
  // Expose sync-in-progress so UI can show a spinner
  static final ValueNotifier<bool> syncInProgress = ValueNotifier<bool>(false);
  // Notify listeners when sync completes so they can refresh
  static final ValueNotifier<int> syncCompleted = ValueNotifier<int>(0);

  static bool _beginSync() {
    if (syncInProgress.value) {
      return false;
    }
    syncInProgress.value = true;
    return true;
  }

  static void _endSync() {
    syncInProgress.value = false;
    // Increment counter to notify all listeners that sync completed
    syncCompleted.value++;
  }

  static void enableConnectivitySync() {
    _connectivitySyncEnabled = true;
  }

  /// Cache all data from remote to local storage
  static Future<void> cacheAllData() async {
    // Avoid overlapping syncs
    final started = _beginSync();
    if (!started) {
      _log('⚠️ Sync already running, skipping cacheAllData');
      return;
    }

    final online = await ConnectivityHelper.hasInternetConnection();
    final treeDB = TreeDB();
    final fruitDB = FruitDB();
    final growthDB = GrowthDB();

    final nowStamp = DateTime.now().toIso8601String();
    if (!online) {
      _log('📴 Offline mode detected at $nowStamp');
      _endSync();
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

      // Fetch and cache AVAILABLE agrochemical master list for offline use
      try {
        final agroTypes = await AgrochemicalApi.getAvailableAgrochemicals();
        await AgroDB().saveAgrochemicalList(agroTypes);
      } catch (e) {
        _log('❌ Error fetching available agrochemicals: $e');
      }

      // 🔄 SYNC PENDING UPDATES FIRST before caching remote trees
      // This ensures pending_update flags are not cleared by upsertTreeFromApi
      try {
        await SyncTrees().syncUnsyncedTrees();
      } catch (e) {
        _log('❌ Error syncing trees: $e');
      }

      // Fetch and cache trees (after pending syncs to preserve pending flags)
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

      // Attempt to sync any pending disease records created while offline
      try {
        await SyncDiseases().syncDiseases();
      } catch (e) {
        _log('❌ Error syncing diseases: $e');
      }

      // Attempt to sync any pending growth logs created while offline
      try {
        await SyncGrowth().syncGrowth();
      } catch (e) {
        _log('❌ Error syncing growth logs: $e');
      }

      final timestamp = DateTime.now().toIso8601String();
      _log('✅ Sync complete at $timestamp');

      // We performed the initial full cache; skip the first reconnect
      // event in the connectivity listener (if it fires immediately after registration)
      _skipFirstReconnect = true;
    } catch (e) {
      _log('❌ Error during cache: $e');
    } finally {
      _endSync();
    }
  }

  static Future<List<TreeModel>> initializeApp() async {
    // Prevent overlapping with other sync operations
    final started = _beginSync();
    if (!started) {
      _log('⚠️ Sync already running, skipping initializeApp');
      return [];
    }

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
        // Fetch and cache AVAILABLE agrochemical master list for offline use
        try {
          final agroTypes = await AgrochemicalApi.getAvailableAgrochemicals();
          await AgroDB().saveAgrochemicalList(agroTypes);
        } catch (e) {
          _log('❌ Error caching available agrochemicals: $e');
        }

        // 🔄 SYNC PENDING UPDATES FIRST before caching remote trees
        // This ensures pending_update flags are not cleared by upsertTreeFromApi
        try {
          await SyncTrees().syncUnsyncedTrees();
        } catch (e) {
          _log('❌ Error syncing trees: $e');
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
          _log('❌ Error syncing agrochemicals in init: $e');
        }
        
        // Attempt to sync any pending disease records created while offline
        try {
          await SyncDiseases().syncDiseases();
        } catch (e) {
          _log('❌ Error syncing diseases in init: $e');
        }

        // Attempt to sync any pending growth logs created while offline
        try {
          await SyncGrowth().syncGrowth();
        } catch (e) {
          _log('❌ Error syncing growth logs in init: $e');
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

    _endSync();
    return trees;
  }

  static void initConnectivityListener() {
    if (_connectivityListenerInitialized) {
      return;
    }
    _connectivityListenerInitialized = true;

    // Initialize last known state so we only fire on true offline -> online transitions
    ConnectivityHelper.hasInternetConnection().then((online) {
      _wasOnline = online;
    });

    Connectivity().onConnectivityChanged.listen((status) async {
      if (!_connectivitySyncEnabled) {
        return;
      }

      final online = await ConnectivityHelper.hasInternetConnection();

      // Reset when offline so the next online event can trigger a sync
      if (!online) {
        _wasOnline = false;
        // Once we've truly gone offline, allow the next reconnect to sync
        _skipFirstReconnect = false;
        return;
      }

      // If requested, skip the first reconnect event to avoid duplicating the init cache
      if (_skipFirstReconnect) {
        _skipFirstReconnect = false;
        _wasOnline = true;
        return;
      }

      // Only sync when transitioning from offline -> online, and avoid overlapping runs
      if (!_wasOnline && !_isSyncing) {
        _isSyncing = true;
        try {
          await cacheAllData();
        } catch (e) {
          _log('❌ Error during reconnect sync: $e');
        } finally {
          _isSyncing = false;
          _wasOnline = true;
        }
      } else {
        _wasOnline = true;
      }
    });
  }
}
