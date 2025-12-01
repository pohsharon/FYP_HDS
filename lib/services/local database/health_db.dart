import 'package:sqflite/sqflite.dart';
import 'package:fyp_hbs/services/local%20database/local_db.dart';
import '../../models/health_model.dart';

class HealthDB {
  // Insert or replace a health record
  Future<int> insertHealth(HealthModel health) async {
  final db = await LocalDB.getDatabase();
    return await db.insert(
      'health_record',
      health.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Fetch all health records
  Future<List<HealthModel>> getAllHealthRecords() async {
  final db = await LocalDB.getDatabase();
    final result = await db.query('health_record');
    return result.map((json) => HealthModel.fromMap(json)).toList();
  }

  // Update health rows for a given tree_uuid
  Future<int> updateHealthByTreeUuid(String treeUuid, Map<String, dynamic> changes, {bool markPendingUpdate = false}) async {
  final db = await LocalDB.getDatabase();
    final updateMap = Map<String, dynamic>.from(changes);
    if (markPendingUpdate) updateMap['pending_update'] = 1;
    return await db.update('health_record', updateMap, where: 'tree_uuid = ?', whereArgs: [treeUuid]);
  }

  // Mark all health rows for a tree as synced
  Future<int> markAsSynced(String treeUuid) async {
  final db = await LocalDB.getDatabase();
    return await db.update('health_record', {'synced': 1, 'pending_update': 0}, where: 'tree_uuid = ?', whereArgs: [treeUuid]);
  }

  // Fetch unsynced health records (synced = 0)
  Future<List<HealthModel>> fetchUnsyncedHealths() async {
  final db = await LocalDB.getDatabase();
    final result = await db.query('health_record', where: 'synced = ?', whereArgs: [0]);
    return result.map((json) => HealthModel.fromMap(json)).toList();
  }

  // Fetch pending updates
  Future<List<HealthModel>> fetchPendingUpdates() async {
  final db = await LocalDB.getDatabase();
    final result = await db.query('health_record', where: 'pending_update = ?', whereArgs: [1]);
    return result.map((json) => HealthModel.fromMap(json)).toList();
  }

  // Fetch pending deletes
  Future<List<HealthModel>> fetchPendingDeletes() async {
  final db = await LocalDB.getDatabase();
    final result = await db.query('health_record', where: 'pending_delete = ?', whereArgs: [1]);
    return result.map((json) => HealthModel.fromMap(json)).toList();
  }

  // Delete health records for a given tree (by tree_uuid)
  Future<int> deleteHealthByTreeUuid(String treeUuid) async {
    final db = await LocalDB.getDatabase();
    return await db.delete('health_record', where: 'tree_uuid = ?', whereArgs: [treeUuid]);
  }

  // Fetch health records for a specific tree_uuid
  Future<List<HealthModel>> fetchByTreeUuid(String treeUuid) async {
    final db = await LocalDB.getDatabase();
    final result = await db.query('health_record', where: 'tree_uuid = ?', whereArgs: [treeUuid], orderBy: 'recorded_at DESC');
    return result.map((json) => HealthModel.fromMap(json)).toList();
  }

  // Cache remote health records into local DB following the preserve-unsynced pattern:
  // 1) Preserve local unsynced/pending rows
  // 2) Delete synced rows for affected tree_uuids only
  // 3) Insert remote rows as synced
  // 4) Reinsert preserved local rows (REPLACE)
  Future<void> cacheRemoteHealth(List<HealthModel> remote) async {
    final db = await LocalDB.getDatabase();

    // optional debug dump omitted

    // Preserve unsynced or pending local rows
    final unsyncedOrPending = await db.query(
      'health_record',
      where: '(synced = ? OR pending_update = ? OR pending_delete = ?)',
      whereArgs: [0, 1, 1],
    );

    // If remote is empty, skip delete/insert to avoid accidental wipes
    if (remote.isEmpty) {
      return;
    }

    // Determine affected tree_uuids
    final affected = <String>{};
    for (final r in remote) {
      try {
        if (r.tree_uuid != null && r.tree_uuid!.isNotEmpty) affected.add(r.tree_uuid!);
      } catch (_) {}
    }

    if (affected.isEmpty) {
      // Fallback: delete all synced rows if we don't know affected trees
  await db.delete('health_record', where: 'synced = ?', whereArgs: [1]);
    } else {
      for (final tu in affected) {
  await db.delete('health_record', where: 'synced = ? AND tree_uuid = ?', whereArgs: [1, tu]);
      }
    }

    // Insert remote rows marked as synced
    for (final r in remote) {
      final m = Map<String, dynamic>.from(r.toMap());
      m['synced'] = 1;
      if (m['recorded_at'] == null || m['recorded_at'].toString().trim().isEmpty) {
        m['recorded_at'] = DateTime.now().toIso8601String();
      }
  await db.insert('health_record', m, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Reinsert preserved local rows with REPLACE to keep unsynced rows intact
    for (final u in unsyncedOrPending) {
      await db.insert('health_record', u, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final total = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM health_record'));
  }
}