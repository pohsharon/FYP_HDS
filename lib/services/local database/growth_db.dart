import 'package:sqflite/sqflite.dart';
import 'local_db.dart';
import '../../models/tree_growth_model.dart';

class GrowthDB{
  Future<int> insertGrowth(TreeGrowthModel g) async {
    final db = await LocalDB.getDatabase();
    final map = g.toMap();
    // Ensure created_at fallback exists
    if (map['created_at'] == null ||
        map['created_at'].toString().trim().isEmpty) {
      map['created_at'] = DateTime.now().toIso8601String();
    }
    return await db.insert(
      'tree_growth',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TreeGrowthModel>> fetchAllGrowths({String? treeUuid}) async {
    final db = await LocalDB.getDatabase();
    final where = treeUuid != null ? 'WHERE tree_uuid = ?' : '';
    final args = treeUuid != null ? [treeUuid] : null;
    // Order newest first (created_at descending)
    final result = await db.rawQuery(
      'SELECT * FROM tree_growth $where ORDER BY created_at DESC',
      args,
    );
    return result.map((r) => TreeGrowthModel.fromMap(r)).toList();
  }

  Future<List<TreeGrowthModel>> fetchUnsyncedGrowths() async {
    final db = await LocalDB.getDatabase();
    final result = await db.query(
      'tree_growth',
      where: 'synced = ?',
      whereArgs: [0],
    );
    return result.map((r) => TreeGrowthModel.fromMap(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchPendingDeletes() async {
    final db = await LocalDB.getDatabase();
    final result = await db.query(
      'tree_growth',
      where: 'pending_delete = ?',
      whereArgs: [1],
    );
    return result;
  }

  Future<List<Map<String, dynamic>>> fetchPendingUpdates() async {
    final db = await LocalDB.getDatabase();
    final result = await db.query(
      'tree_growth',
      where: 'pending_update = ? AND pending_delete = ?',
      whereArgs: [1, 0],
    );
    return result;
  }

  Future<int> markGrowthAsSynced(String uuid) async {
    final db = await LocalDB.getDatabase();
    return await db.update(
      'tree_growth',
      {'synced': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<int> markGrowthAsPendingUpdate(String uuid) async {
    final db = await LocalDB.getDatabase();
    return await db.update(
      'tree_growth',
      {'pending_update': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<int> markGrowthAsPendingDelete(String uuid) async {
    final db = await LocalDB.getDatabase();
    return await db.update(
      'tree_growth',
      {'pending_delete': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<int> updateGrowthByUuid(
    String uuid,
    Map<String, dynamic> changes, {
    bool markPending = false,
  }) async {
    final db = await LocalDB.getDatabase();
    final updateMap = Map<String, dynamic>.from(changes);
    updateMap.remove('id');
    if (markPending) updateMap['pending_update'] = 1;
    return await db.update(
      'tree_growth',
      updateMap,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<int> deleteGrowthByUuid(String uuid) async {
    final db = await LocalDB.getDatabase();
    return await db.delete('tree_growth', where: 'uuid = ?', whereArgs: [uuid]);
  }

  Future<int> deleteAllGrowths() async {
    final db = await LocalDB.getDatabase();
    return await db.delete('tree_growth');
  }

  Future<void> cacheRemoteGrowths(List<TreeGrowthModel> remote) async {
    final db = await LocalDB.getDatabase();

    try {
      final before = await db.query('tree_growth');
    } catch (e) {
      print('⚠️ cacheRemoteGrowths: failed to dump before rows: $e');
    }

    // Preserve unsynced or pending local rows
    final unsyncedOrPending = await db.query(
      'tree_growth',
      where: '(synced = ? OR pending_update = ? OR pending_delete = ?)',
      whereArgs: [0, 1, 1],
    );

    // If the remote batch is empty, do not delete existing synced rows.
    // An empty remote list likely means "no change" rather than an instruction
    // to wipe local caches. Skipping avoids accidental global deletes when the
    // caller invokes cacheRemoteGrowths per-tree and the server returns 0 rows.
    if (remote.isEmpty) {
      return;
    }

    // Determine which tree_uuids are present in this remote batch so we only
    // delete synced rows for those trees (avoids wiping cached rows for other trees
    // when cacheRemoteGrowths is called per-tree).
    final affectedTreeUuids = <String>{};
    for (final r in remote) {
      try {
        if (r.treeUuid.isNotEmpty) affectedTreeUuids.add(r.treeUuid);
      } catch (_) {}
    }

    if (affectedTreeUuids.isEmpty) {
      // Fallback: delete all synced rows if we don't know which trees are affected
      await db.delete('tree_growth', where: 'synced = ?', whereArgs: [1]);
    } else {
      for (final tu in affectedTreeUuids) {
        await db.delete(
          'tree_growth',
          where: 'synced = ? AND tree_uuid = ?',
          whereArgs: [1, tu],
        );
      }
    }

    // Insert remote rows (mark as synced). Use IGNORE so we don't clobber preserved rows with same uuid.
    for (var i = 0; i < remote.length; i++) {
      final r = remote[i];
      final m = Map<String, dynamic>.from(r.toMap());
      m['synced'] = 1;
      if (m['created_at'] == null ||
          m['created_at'].toString().trim().isEmpty) {
        m['created_at'] = DateTime.now().toIso8601String();
      }
      await db.insert(
        'tree_growth',
        m,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // Reinsert preserved local rows with REPLACE so they overwrite any remote-inserted rows
    for (final u in unsyncedOrPending) {
      await db.insert(
        'tree_growth',
        u,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final total = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM tree_growth'),
    );
  }

  /// Replace tree_uuid for growth rows when an offline-created tree receives
  /// a server UUID. This remaps local growth entries so they reference the
  /// server tree before sync.
  Future<int> reassignTreeUuid(String oldUuid, String newUuid) async {
    final db = await LocalDB.getDatabase();
    return await db.update(
      'tree_growth',
      {'tree_uuid': newUuid},
      where: 'tree_uuid = ?',
      whereArgs: [oldUuid],
    );
  }
}