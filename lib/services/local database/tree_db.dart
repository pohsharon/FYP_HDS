import 'package:sqflite/sqflite.dart';
import 'local_db.dart';
import '../../models/tree_model.dart';

class TreeDB{
  Future<int> insertTree(TreeModel tree) async {
    final db = await LocalDB.getDatabase();
    final map = tree.toMap();
    final res = await db.insert(
      'trees',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return res;
  }

  Future<List<TreeModel>> fetchAllTrees() async {
    final db = await LocalDB.getDatabase();
    final result = await db.query('trees');
    return result.map((e) => TreeModel.fromMap(e)).toList();
  }

  Future<List<TreeModel>> fetchUnsyncedTrees() async {
    final db = await LocalDB.getDatabase();
    final result = await db.query('trees', where: 'synced = ?', whereArgs: [0]);
    return result.map((e) => TreeModel.fromMap(e)).toList();
  }

  Future<int> markAsSynced(String uuid) async {
    final db = await LocalDB.getDatabase();
    final updated = await db.update(
      'trees',
      {'synced': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return updated;
  }

  Future<int> markAsSyncedByTag(String treeTag) async {
    final db = await LocalDB.getDatabase();
    final updated = await db.update(
      'trees',
      {'synced': 1},
      where: 'tree_tag = ?',
      whereArgs: [treeTag],
    );
    return updated;
  }

  Future<int> deleteAllTrees() async {
    final db = await LocalDB.getDatabase();
    return await db.delete('trees');
  }

  Future close() async {
    final db = await LocalDB.getDatabase();
    db.close();
  }

  Future<int> markAsPendingUpdate(String uuid) async {
    final db = await LocalDB.getDatabase();
    return await db.update(
      'trees',
      {'pending_update': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<int> markAsPendingDelete(String uuid) async {
    final db = await LocalDB.getDatabase();
    return await db.update(
      'trees',
      {'pending_delete': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<List<TreeModel>> fetchPendingUpdates() async {
    final db = await LocalDB.getDatabase();
    final result = await db.query(
      'trees',
      where: 'pending_update = ?',
      whereArgs: [1],
    );
    return result.map((e) => TreeModel.fromMap(e)).toList();
  }

  Future<List<TreeModel>> fetchPendingDeletes() async {
    final db = await LocalDB.getDatabase();
    final result = await db.query(
      'trees',
      where: 'pending_delete = ?',
      whereArgs: [1],
    );
    return result.map((e) => TreeModel.fromMap(e)).toList();
  }

  Future<int> deleteTreeByUuid(String uuid) async {
    final db = await LocalDB.getDatabase();
    return await db.delete('trees', where: 'uuid = ?', whereArgs: [uuid]);
  }

  Future<int> updateTreeByUuid(
    String uuid,
    Map<String, dynamic> changes, {
    bool markPendingUpdate = false,
  }) async {
    final db = await LocalDB.getDatabase();
    final updateMap = Map<String, dynamic>.from(changes);
    // Remove id if present to avoid trying to update primary key unintentionally
    updateMap.remove('id');
    if (markPendingUpdate) updateMap['pending_update'] = 1;
    final rows = await db.update(
      'trees',
      updateMap,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return rows;
  }

  Future<int> clearPendingUpdate(String uuid) async {
    final db = await LocalDB.getDatabase();
    return await db.update(
      'trees',
      {'pending_update': 0, 'synced': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<void> cacheRemoteTrees(List<TreeModel> remoteTrees) async {
    final db = await LocalDB.getDatabase();

    try {
      await db.query('trees');
    } catch (_) {}

    // Preserve rows that are unsynced (synced=0) OR have pending updates/deletes
    final unsyncedOrPending = await db.query(
      'trees',
      where: '(synced = ? OR pending_update = ? OR pending_delete = ?)',
      whereArgs: [0, 1, 1],
    );

    // Step 2: Delete only synced ones WITHOUT pending updates/deletes
    await db.delete('trees', 
      where: 'synced = ? AND pending_update = ? AND pending_delete = ?', 
      whereArgs: [1, 0, 0]);

    // Step 3: Insert remote trees (marked as synced)
    // Use IGNORE so remote rows don't overwrite local pending rows
    for (final tree in remoteTrees) {
      await db.insert('trees', {
        ...tree.toMap(),
        'synced': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Step 4: Reinsert preserved local rows (unsynced or pending)
    // Use REPLACE to overwrite remote data with pending local changes
    for (final u in unsyncedOrPending) {
      await db.insert('trees', u, conflictAlgorithm: ConflictAlgorithm.replace);
    }

  }

  /// Reassign a tree's uuid from [oldUuid] to [newUuid]. This is used when
  /// the server returns a different authoritative UUID for a tree that was
  /// created offline locally. We update the local `trees` row so child
  /// records can be remapped to the server UUID before syncing them.
  Future<int> reassignUuid(String oldUuid, String newUuid) async {
    final db = await LocalDB.getDatabase();
    return await db.update(
      'trees',
      {'uuid': newUuid},
      where: 'uuid = ?',
      whereArgs: [oldUuid],
    );
  }

  /// Upsert a single tree from API response into local cache. This is used
  /// when fetching tree details or updating a tree online to immediately
  /// reflect changes in the local DB so offline mode shows current data.
  Future<void> upsertTreeFromApi(Map<String, dynamic> apiTree) async {
    final db = await LocalDB.getDatabase();
    
    final uuid = (apiTree['uuid'] ?? apiTree['id'])?.toString();
    if (uuid == null || uuid.isEmpty) return;

    final plantedRaw = apiTree['planted_at'] ?? apiTree['plantedAt'];
    String? plantedIso;
    if (plantedRaw != null) {
      try {
        plantedIso = DateTime.parse(plantedRaw.toString()).toIso8601String();
      } catch (_) {
        plantedIso = plantedRaw.toString();
      }
    }

    double? asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    int? asInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    final values = {
      'uuid': uuid,
      'tree_tag': apiTree['tree_tag'] ?? apiTree['treeTag'] ?? apiTree['tag'],
      'species_id': apiTree['species']?['id']?.toString() ?? apiTree['species_id']?.toString(),
      'planted_at': plantedIso,
      'height': asDouble(apiTree['height']),
      'diameter': asDouble(apiTree['diameter'] ?? apiTree['width']),
      'flowering_period': asInt(apiTree['flowering_period']),
      'thumbnail': apiTree['thumbnail'],
      'latitude': asDouble(apiTree['latitude']),
      'longitude': asDouble(apiTree['longitude']),
      'updated_at': (apiTree['updated_at'] ?? apiTree['updatedAt'] ?? DateTime.now().toIso8601String()).toString(),
      'synced': 1,
      'pending_update': 0,
      'pending_delete': 0,
    };

    // Update existing row by uuid; insert if missing so offline views reuse latest copy.
    final updated = await db.update(
      'trees',
      values,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    if (updated == 0) {
      await db.insert(
        'trees',
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Remove older duplicates for this uuid to avoid stale reads in offline mode.
    await db.delete(
      'trees',
      where: 'uuid = ? AND rowid NOT IN (SELECT MAX(rowid) FROM trees WHERE uuid = ?)',
      whereArgs: [uuid, uuid],
    );
  }
}