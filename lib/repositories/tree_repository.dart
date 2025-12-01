import 'dart:io';
import '../models/tree_model.dart';
import '../services/local database/tree_db.dart';
import '../services/api/tree_api.dart';

class TreeRepository {
  final TreeDB _localDB = TreeDB();
  List<TreeModel>? _cachedTrees;
  DateTime? _lastFetch;
  Future<List<TreeModel>>? _ongoingFetch;

  // Cache TTL in seconds
  static const int _cacheTtlSeconds = 60;

  Future<List<TreeModel>> getTrees({bool forceRefresh = false}) async {
    try {
      // If we have a recent cached copy and refresh isn't forced, return it
      if (!forceRefresh && _cachedTrees != null && _lastFetch != null) {
        final age = DateTime.now().difference(_lastFetch!).inSeconds;
        if (age < _cacheTtlSeconds) {
          return _cachedTrees!;
        }
      }

      // If a fetch is already in progress, await it to dedupe concurrent callers
      if (_ongoingFetch != null) {
        return await _ongoingFetch!;
      }

      // Start remote fetch and store the future so other callers can await it
      _ongoingFetch = () async {
        // Try to fetch from Supabase (backend)
        final response = await TreeApi.fetchAllTrees();
        final treeList = response['data']['data'] as List<dynamic>;

        // Convert and store locally
        List<TreeModel> trees = treeList.map((tree) {
        return TreeModel(
          uuid: tree['uuid'],
          treeTag: tree['tree_tag'] ?? '',
          // Ensure speciesId is stored as a string (API may return numeric id)
          speciesId: tree['species']?['id']?.toString() ?? tree['species_id']?.toString(),
          plantedAt: DateTime.parse(tree['planted_at'] ?? DateTime.now().toIso8601String()),
          thumbnail: tree['thumbnail'],
          latitude: double.tryParse(tree['latitude']?.toString() ?? '') ?? (tree['latitude'] is num ? (tree['latitude'] as num).toDouble() : 0.0),
          longitude: double.tryParse(tree['longitude']?.toString() ?? '') ?? (tree['longitude'] is num ? (tree['longitude'] as num).toDouble() : 0.0),
          floweringPeriod: (() {
            final fp = tree['flowering_period'];
            if (fp is num) return fp.toInt();
            return int.tryParse(fp?.toString() ?? '') ?? 0;
          })(),
          // These records come from the server, so mark them as already synced locally
          synced: 1,
        );
        }).toList();

        // update in-memory cache
        _cachedTrees = trees;
        _lastFetch = DateTime.now();

        try {
          final allLocal = await _localDB.fetchAllTrees();
          print('📦 After caching, local DB has ${allLocal.length} trees');
        } catch (e) {
          print('⚠️ Error reading local DB after caching: $e');
        }

        return trees;
      }();

      try {
        final result = await _ongoingFetch!;
        return result;
      } finally {
        _ongoingFetch = null;
      }
    } on SocketException catch (_) {
      print("📴 Offline mode — loading from local DB");
      return await _localDB.fetchAllTrees();
    } catch (e) {
print("❌ Error loading trees: $e — loading local cache instead");
      return await _localDB.fetchAllTrees();
    }
  }
}
