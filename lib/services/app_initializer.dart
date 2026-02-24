import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
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
import 'dart:async';

class AppInitializer {
  /// When true, all automatic sync / offline caching activities are skipped.
  /// Use this for temporary debugging or to disable network sync during testing.
  /// Toggle at runtime via `AppInitializer.temporarilyDisableSync = true`.
  static bool temporarilyDisableSync = false;

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
  // If true, a running sync should abort as soon as practical
  static bool _abortSyncRequested = false;
  // Track whether the last sync run was aborted (used to show different Flushbar)
  static bool _lastSyncAborted = false;

  // Maximum allowed duration for a full sync run before we force-abort
  static const Duration _maxSyncDuration = Duration(seconds: 30);

  // Public accessor so other services can check whether an abort was requested
  static bool get isAbortRequested => _abortSyncRequested;
  // Expose sync-in-progress so UI can show a spinner
  static final ValueNotifier<bool> syncInProgress = ValueNotifier<bool>(false);
  // Notify listeners when sync completes so they can refresh
  static final ValueNotifier<int> syncCompleted = ValueNotifier<int>(0);
  // Global navigator key for showing Flushbars from anywhere
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  // Track sync notifications
  static Flushbar<dynamic>? _syncStartedFlushbar;
  static Flushbar<dynamic>? _syncCompletedFlushbar;

  static bool _beginSync() {
    if (syncInProgress.value) {
      return false;
    }
    // Reset abort state when a fresh sync begins
    _abortSyncRequested = false;
    _lastSyncAborted = false;
    syncInProgress.value = true;
    _showSyncStartedFlushbar();
    return true;
  }

  static void _endSync() {
    syncInProgress.value = false;
    // Increment counter to notify all listeners that sync completed
    syncCompleted.value++;
    // Print pending sync counts for each type
    printPendingSyncCounts();
    // If the last sync was aborted due to connectivity loss, show an abort message
    if (_lastSyncAborted) {
      try {
        final context = navigatorKey.currentContext;
        if (context != null) {
          Flushbar(message: 'Sync aborted: connection lost.',
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(12),
            borderRadius: BorderRadius.circular(8),
            flushbarPosition: FlushbarPosition.TOP,
          ).show(context);
        }
      } catch (_) {}
      _lastSyncAborted = false;
      return;
    }

    _showSyncCompletedFlushbar();
  }

  /// Count and print pending syncs for each record type separately
  static Future<void> printPendingSyncCounts() async {
    try {
      // print('🔍 Checking pending syncs...');

      // Count unsynced trees
      try {
        final treeDB = TreeDB();
        final unsyncedTrees = await treeDB.fetchUnsyncedTrees();
        // print('🌳 Unsynced Trees: ${unsyncedTrees.length}');
      } catch (e) {
        print('⚠️ Error counting pending trees: $e');
      }

      // Count unsynced fruits
      try {
        final fruitDB = FruitDB();
        final unsyncedFruits = await fruitDB.getUnsyncedFruits();
        // print('🍎 Unsynced Fruits: ${unsyncedFruits.length}');
      } catch (e) {
        print('⚠️ Error counting pending fruits: $e');
      }

      // Count unsynced health records
      try {
        final healthDB = HealthDB();
        final unsyncedHealth = await healthDB.fetchUnsyncedHealths();
        // print('❤️ Unsynced Health Records: ${unsyncedHealth.length}');
      } catch (e) {
        print('⚠️ Error counting pending health records: $e');
      }

      // Count unsynced agrochemical records
      try {
        final agroDB = AgroDB();
        final unsyncedAgro = await agroDB.fetchUnsyncedAgrochemicals();
        // print('🧪 Unsynced Agrochemical Records: ${unsyncedAgro.length}');
      } catch (e) {
        print('⚠️ Error counting pending agrochemical records: $e');
      }

      // Count unsynced growth records
      try {
        final growthDB = GrowthDB();
        final unsyncedGrowth = await growthDB.fetchUnsyncedGrowths();
        // print('📈 Unsynced Growth Records: ${unsyncedGrowth.length}');
      } catch (e) {
        print('⚠️ Error counting pending growth records: $e');
      }

      // Count unsynced disease records
      try {
        final diseaseDB = DiseaseDB();
        final unsyncedDisease = await diseaseDB.fetchUnsyncedDiseases();
        // print('🦠 Unsynced Disease Records: ${unsyncedDisease.length}');
      } catch (e) {
        print('⚠️ Error counting pending disease records: $e');
      }

      // print('✅ Pending sync check completed');
    } catch (e) {
      print('❌ Error checking pending syncs: $e');
    }
  }

  static void _showSyncStartedFlushbar() {
    try {
      final context = navigatorKey.currentContext;
      if (context == null) return;
      
      // Dismiss previous flushbars
      _syncStartedFlushbar?.dismiss();
      _syncCompletedFlushbar?.dismiss();
      
      _syncStartedFlushbar = Flushbar(
        message: '🌐 Syncing in progress...',
        backgroundColor: Colors.blue.shade700,
        duration: const Duration(days: 1), // Long duration, will be dismissed manually
        margin: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(8),
        flushbarPosition: FlushbarPosition.TOP,
      );
      
      _syncStartedFlushbar?.show(context);
    } catch (e) {
      _log('⚠️ Error showing sync started notification: $e');
    }
  }

  static void _showSyncCompletedFlushbar() {
    try {
      final context = navigatorKey.currentContext;
      if (context == null) return;
      
      // Dismiss the started flushbar
      _syncStartedFlushbar?.dismiss();
      
      // Get current timestamp
      final now = DateTime.now();
      final timestamp = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      
      _syncCompletedFlushbar = Flushbar(
        message: 'Sync completed at $timestamp',
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(8),
        flushbarPosition: FlushbarPosition.TOP,
      );
      
      _syncCompletedFlushbar?.show(context);
    } catch (e) {
      _log('⚠️ Error showing sync completed notification: $e');
    }
  }

  static void enableConnectivitySync() {
    if (temporarilyDisableSync) {
      _log('🔕 enableConnectivitySync skipped (temporarilyDisableSync=true)');
      return;
    }

    _connectivitySyncEnabled = true;
  }

  /// Cache all data from remote to local storage
  static Future<void> cacheAllData() async {
    if (temporarilyDisableSync) {
      _log('🔕 cacheAllData skipped (temporarilyDisableSync=true)');
      return;
    }
    // Avoid overlapping syncs
    final started = _beginSync();
    if (!started) {
      _log('⚠️ Sync already running, skipping cacheAllData');
      return;
    }
    // Listen for connectivity changes during this sync so we can abort early
    _abortSyncRequested = false;
    _lastSyncAborted = false;
    final sub = Connectivity().onConnectivityChanged.listen((_) async {
      final onlineNow = await ConnectivityHelper.hasInternetConnection();
      if (!onlineNow) {
        _abortSyncRequested = true;
        _lastSyncAborted = true;
        _log('⚠️ Connectivity lost during sync — abort requested');
      }
    });

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
    _log('🌐 Online mode detected at $nowStamp');

    // Run the sync body with an overall timeout so it cannot hang indefinitely
    Future<void> runSyncBody() async {
      try {
        // existing sync steps
        
        // Fetch species
        try {
          await TreeApi.fetchSpecies();
        } catch (e) {
          _log('❌ Error fetching species: $e');
        }

        if (_abortSyncRequested) throw Exception('Sync aborted due to connectivity loss');

        // Fetch and cache disease list for offline use
        try {
          final remoteDiseases = await DiseaseApi.fetchDiseases();
          await DiseaseDB().saveDiseaseList(remoteDiseases);
        } catch (e) {
          _log('❌ Error fetching diseases: $e');
        }

        if (_abortSyncRequested) throw Exception('Sync aborted due to connectivity loss');

        // Fetch and cache AVAILABLE agrochemical master list for offline use
        try {
          final agroTypes = await AgrochemicalApi.getAvailableAgrochemicals();
          await AgroDB().saveAgrochemicalList(agroTypes);
        } catch (e) {
          _log('❌ Error fetching available agrochemicals: $e');
        }

        if (_abortSyncRequested) throw Exception('Sync aborted due to connectivity loss');

        // 🔄 SYNC PENDING UPDATES FIRST before caching remote trees
        try {
          await SyncTrees().syncUnsyncedTrees();
        } catch (e) {
          _log('❌ Error syncing trees: $e');
        }

        if (_abortSyncRequested) throw Exception('Sync aborted due to connectivity loss');

        // Fetch and cache trees (after pending syncs to preserve pending flags)
        final repo = TreeRepository();
        final trees = await repo.getTrees(forceRefresh: true);
        await treeDB.cacheRemoteTrees(trees);

        if (_abortSyncRequested) throw Exception('Sync aborted due to connectivity loss');

        // Fetch and cache fruits for offline use
        // try {
        //   final remoteFruits = await FruitApi.fetchFruits();
        //   final fruitModels = remoteFruits.map((f) => FruitModel.fromMap(f)).toList();
        //   await fruitDB.cacheRemoteFruits(fruitModels);
        // } catch (e) {
        //     _log('❌ Error fetching fruits: $e');
        // }

        if (_abortSyncRequested) throw Exception('Sync aborted due to connectivity loss');

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

        if (_abortSyncRequested) throw Exception('Sync aborted due to connectivity loss');

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

        if (_abortSyncRequested) throw Exception('Sync aborted due to connectivity loss');

        // Fetch and cache growth logs once, then group them per-tree before caching
        try {
          final remoteGrowth = await TreeGrowthApi.fetchAllGrowthLogs();
          final growthModels = remoteGrowth.map((g) => TreeGrowthModel.fromMap(g)).toList();
          await growthDB.cacheRemoteGrowths(growthModels);
        } catch (e) {
          _log('❌ Error fetching growth logs: $e');
        }

        if (_abortSyncRequested) throw Exception('Sync aborted due to connectivity loss');

        // Fetch and cache harvest events for offline use
        try {
          final harvestDB = HarvestDB();
          await harvestDB.fetchAndCacheFromCloud();
        } catch (e) {
          _log('❌ Error fetching harvest events: $e');
        }

        if (_abortSyncRequested) throw Exception('Sync aborted due to connectivity loss');

        // Also attempt to sync any fruits that were created offline
        try {
          await SyncFruits().syncFruits();
        } catch (e) {
          _log('❌ Error syncing fruits: $e');
        }

        if (_abortSyncRequested) throw Exception('Sync aborted due to connectivity loss');

        // Attempt to sync any pending health records created while offline
        try {
          await SyncHealth().syncHealth();
        } catch (e) {
          _log('❌ Error syncing health: $e');
        }

        if (_abortSyncRequested) throw Exception('Sync aborted due to connectivity loss');

        // Attempt to sync any pending agrochemical records created while offline
        try {
          await SyncAgro().syncAgro();
        } catch (e) {
          _log('❌ Error syncing agrochemicals: $e');
        }

        if (_abortSyncRequested) throw Exception('Sync aborted due to connectivity loss');

        // Attempt to sync any pending disease records created while offline
        try {
          await SyncDiseases().syncDiseases();
        } catch (e) {
          _log('❌ Error syncing diseases: $e');
        }

        if (_abortSyncRequested) throw Exception('Sync aborted due to connectivity loss');

        // Attempt to sync any pending growth logs created while offline
        try {
          await SyncGrowth().syncGrowth();
        } catch (e) {
          _log('❌ Error syncing growth logs: $e');
        }

        final timestamp = DateTime.now().toIso8601String();
        _log('✅ Sync complete at $timestamp');
      } finally {
        // nothing here; outer finally will handle cleanup
      }
    }

    try {
      // Start a watchdog timer that forces abort if the sync takes too long.
      Timer? watchdog;
      watchdog = Timer(_maxSyncDuration, () async {
        _log('❌ Watchdog: Sync exceeded $_maxSyncDuration — forcing abort');
        _abortSyncRequested = true;
        _lastSyncAborted = true;
        try { await sub.cancel(); } catch (_) {}
        try {
          // Force UI update to clear long-running flushbar
          _endSync();
        } catch (_) {}
      });

      try {
        await runSyncBody().timeout(_maxSyncDuration);
      } finally {
        watchdog.cancel();
      }
    } on TimeoutException {
      _log('❌ Sync exceeded $_maxSyncDuration — forcing abort');
      _abortSyncRequested = true;
      _lastSyncAborted = true;
    } catch (e) {
      _log('❌ Error during cache: $e');
    } finally {
      // Ensure connectivity listener is torn down
      try { await sub.cancel(); } catch (_) {}
      // Mark that the last sync was aborted if requested
      if (_abortSyncRequested) _lastSyncAborted = true;
      _endSync();
    }
    
    // We performed the initial full cache; skip the first reconnect
    // event in the connectivity listener (if it fires immediately after registration)
    _skipFirstReconnect = true;
  }

  static Future<List<TreeModel>> initializeApp() async {
    if (temporarilyDisableSync) {
      _log('🔕 initializeApp skipped (temporarilyDisableSync=true) — returning local cache only');
      try {
        final treeDB = TreeDB();
        final trees = await treeDB.fetchAllTrees();
        return trees;
      } catch (e) {
        _log('⚠️ Error fetching local trees while sync disabled: $e');
        return [];
      }
    }
    // Prevent overlapping with other sync operations
    final started = _beginSync();
    if (!started) {
      _log('⚠️ Sync already running, skipping initializeApp');
      return [];
    }
    // Setup connectivity watcher so we can abort init if connection drops
    _abortSyncRequested = false;
    _lastSyncAborted = false;
    final sub = Connectivity().onConnectivityChanged.listen((_) async {
      final onlineNow = await ConnectivityHelper.hasInternetConnection();
      if (!onlineNow) {
        _abortSyncRequested = true;
        _lastSyncAborted = true;
        _log('⚠️ Connectivity lost during init — abort requested');
      }
    });

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
      // Start a watchdog timer for initialization to force abort if it hangs
      Timer? watchdog;
      watchdog = Timer(_maxSyncDuration, () async {
        _log('❌ Watchdog: Init exceeded $_maxSyncDuration — forcing abort');
        _abortSyncRequested = true;
        _lastSyncAborted = true;
        try { await sub.cancel(); } catch (_) {}
        try { _endSync(); } catch (_) {}
      });

      try {
        try {
          await TreeApi.fetchSpecies();
        } catch (e) {
          _log('❌ Error fetching species: $e');
        }
        if (_abortSyncRequested) throw Exception('Init aborted due to connectivity loss');
        // Fetch and cache disease list for offline use
        try {
          final remoteDiseases = await DiseaseApi.fetchDiseases();
          await DiseaseDB().saveDiseaseList(remoteDiseases);
        } catch (e) {
          _log('❌ Error caching diseases: $e');
        }
        if (_abortSyncRequested) throw Exception('Init aborted due to connectivity loss');
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
        if (_abortSyncRequested) throw Exception('Init aborted due to connectivity loss');

        final repo = TreeRepository();
        // Force a fresh remote fetch during initialization
        trees = await repo.getTrees(forceRefresh: true);
        await treeDB.cacheRemoteTrees(trees);
        if (_abortSyncRequested) throw Exception('Init aborted due to connectivity loss');
        // Fetch and cache fruits for offline use
        // try {
        //   final remoteFruits = await FruitApi.fetchFruits();
        //   final fruitModels = remoteFruits.map((f) => FruitModel.fromMap(f)).toList();
        //   await fruitDB.cacheRemoteFruits(fruitModels);
        // } catch (e) {
        //   _log('❌ Error caching fruits: $e');
        // }
        if (_abortSyncRequested) throw Exception('Init aborted due to connectivity loss');
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
          if (_abortSyncRequested) throw Exception('Init aborted due to connectivity loss');
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
        if (_abortSyncRequested) throw Exception('Init aborted due to connectivity loss');

        // Attempt to sync any pending health records created while offline
        try {
          await SyncHealth().syncHealth();
        } catch (e) {
          _log('❌ Error syncing health in init: $e');
        }
        if (_abortSyncRequested) throw Exception('Init aborted due to connectivity loss');
        // Attempt to sync any pending agrochemical records created while offline
        try {
          await SyncAgro().syncAgro();
        } catch (e) {
          _log('❌ Error syncing agrochemicals in init: $e');
        }
        if (_abortSyncRequested) throw Exception('Init aborted due to connectivity loss');
        
        // Attempt to sync any pending disease records created while offline
        try {
          await SyncDiseases().syncDiseases();
        } catch (e) {
          _log('❌ Error syncing diseases in init: $e');
        }
        if (_abortSyncRequested) throw Exception('Init aborted due to connectivity loss');

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
      finally {
        watchdog.cancel();
      }
    }

    // Clean up connectivity listener and end sync. Ensure we record aborted state
    try { await sub.cancel(); } catch (_) {}
    if (_abortSyncRequested) _lastSyncAborted = true;
    _endSync();
    return trees;
  }

  static void initConnectivityListener() {
    if (_connectivityListenerInitialized) {
      return;
    }
    if (temporarilyDisableSync) {
      _log('🔕 initConnectivityListener skipped (temporarilyDisableSync=true)');
      return;
    }
    _connectivityListenerInitialized = true;

    // Print initial pending sync counts at startup
    printPendingSyncCounts();

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
