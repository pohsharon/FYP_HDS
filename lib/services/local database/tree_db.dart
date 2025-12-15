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
    return await db.update(
      'trees',
      updateMap,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
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
      final beforeAll = await db.query('trees');
      print('ℹ️ cacheRemoteTrees: rows before caching=${beforeAll.length}');
    } catch (e) {
      print('⚠️ cacheRemoteTrees: error dumping rows before caching: $e');
    }

    // Preserve rows that are unsynced (synced=0) OR have pending updates/deletes
    final unsyncedOrPending = await db.query(
      'trees',
      where: '(synced = ? OR pending_update = ? OR pending_delete = ?)',
      whereArgs: [0, 1, 1],
    );
    print(
      '📦 Preserving ${unsyncedOrPending.length} local rows (unsynced or pending) before caching remote data',
    );
    if (unsyncedOrPending.isNotEmpty) {
      for (final u in unsyncedOrPending) {
        print(
          '   • preserving -> uuid=${u['uuid']}, tree_tag=${u['tree_tag']}, synced=${u['synced']}, pending_update=${u['pending_update']}, pending_delete=${u['pending_delete']}',
        );
      }
    }

    // Step 2: Delete only synced ones
    await db.delete('trees', where: 'synced = ?', whereArgs: [1]);

    // Step 3: Insert remote trees (marked as synced)
    for (final tree in remoteTrees) {
      await db.insert('trees', {
        ...tree.toMap(),
        'synced': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Step 4: Reinsert preserved local rows (unsynced or pending)
    for (final u in unsyncedOrPending) {
      await db.insert('trees', u, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final total = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM trees'),
    );
    print('✅ Local cache updated. Total trees in DB: $total');
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
}