import 'package:sqflite/sqflite.dart';
import 'package:fyp_hbs/services/local%20database/local_db.dart';
import '../../models/agrochemical_model.dart';

class AgroDB {
  // Insert or replace an agrochemical record
  Future<int> insertAgrochemical(AgrochemicalModel agrochemical) async {
  final db = await LocalDB.getDatabase();
    return await db.insert(
      'agrochemical_record',
      agrochemical.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Fetch all agrochemical records
  Future<List<AgrochemicalModel>> getAllAgrochemicalRecords() async {
  final db = await LocalDB.getDatabase();
    final result = await db.query('agrochemical_record');
    return result.map((json) => AgrochemicalModel.fromMap(json)).toList();
  }

  // Update agrochemical rows for a given tree_uuid
  Future<int> updateAgrochemicalByTreeUuid(String treeUuid, Map<String, dynamic> changes, {bool markPendingUpdate = false}) async {
  final db = await LocalDB.getDatabase();
    final updateMap = Map<String, dynamic>.from(changes);
    if (markPendingUpdate) updateMap['pending_update'] = 1;
    return await db.update('agrochemical_record', updateMap, where: 'tree_uuid = ?', whereArgs: [treeUuid]);
  }

  // Mark all agrochemical rows for a tree as synced
  Future<int> markAsSynced(String treeUuid) async {
  final db = await LocalDB.getDatabase();
    return await db.update('agrochemical_record', {'synced': 1, 'pending_update': 0}, where: 'tree_uuid = ?', whereArgs: [treeUuid]);
  }

  // Fetch unsynced agrochemical records (synced = 0)
  Future<List<AgrochemicalModel>> fetchUnsyncedAgrochemicals() async {
  final db = await LocalDB.getDatabase();
    final result = await db.query('agrochemical_record', where: 'synced = ?', whereArgs: [0]);
    return result.map((json) => AgrochemicalModel.fromMap(json)).toList();
  }

  // Fetch pending updates
  Future<List<AgrochemicalModel>> fetchPendingUpdates() async {
  final db = await LocalDB.getDatabase();
    final result = await db.query('agrochemical_record', where: 'pending_update = ?', whereArgs: [1]);
    return result.map((json) => AgrochemicalModel.fromMap(json)).toList();
  }

  // Fetch pending deletes
  Future<List<AgrochemicalModel>> fetchPendingDeletes() async {
  final db = await LocalDB.getDatabase();
    final result = await db.query('agrochemical_record', where: 'pending_delete = ?', whereArgs: [1]);
    return result.map((json) => AgrochemicalModel.fromMap(json)).toList();
  }

  // Delete agrochemical records for a given tree (by tree_uuid)
  Future<int> deleteAgrochemicalByTreeUuid(String treeUuid) async {
    final db = await LocalDB.getDatabase();
    return await db.delete('agrochemical_record', where: 'tree_uuid = ?', whereArgs: [treeUuid]);
  }

  // Fetch agrochemical records for a specific tree_uuid
  Future<List<AgrochemicalModel>> fetchByTreeUuid(String treeUuid) async {
    final db = await LocalDB.getDatabase();
    final result = await db.query('agrochemical_record', where: 'tree_uuid = ?', whereArgs: [treeUuid], orderBy: 'applied_at DESC');
    return result.map((json) => AgrochemicalModel.fromMap(json)).toList();
  }

  // Cache remote health records into local DB following the preserve-unsynced pattern:
  // 1) Preserve local unsynced/pending rows
  // 2) Delete synced rows for affected tree_uuids only
  // 3) Insert remote rows as synced
  // 4) Reinsert preserved local rows (REPLACE)
  Future<void> cacheRemoteAgrochemical(List<AgrochemicalModel> remote) async {
    final db = await LocalDB.getDatabase();

    // optional debug dump omitted

    // Preserve unsynced or pending local rows
    final unsyncedOrPending = await db.query(
      'agrochemical_record',
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
      await db.delete('agrochemical_record', where: 'synced = ?', whereArgs: [1]);
    } else {
      for (final tu in affected) {
        await db.delete('agrochemical_record', where: 'synced = ? AND tree_uuid = ?', whereArgs: [1, tu]);
      }
    }

    // Insert remote rows marked as synced
    for (final r in remote) {
      final m = Map<String, dynamic>.from(r.toMap());
      m['synced'] = 1;
      if (m['applied_at'] == null || m['applied_at'].toString().trim().isEmpty) {
        m['applied_at'] = DateTime.now().toIso8601String();
      }
      await db.insert('agrochemical_record', m, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Reinsert preserved local rows with REPLACE to keep unsynced rows intact
    for (final u in unsyncedOrPending) {
      await db.insert('agrochemical_record', u, conflictAlgorithm: ConflictAlgorithm.replace);
    }

  }

  // Save master list of agrochemical types (from API) into `agrochemical` lookup table
  Future<void> saveAgrochemicalList(List<Map<String, dynamic>> list) async {
    final db = await LocalDB.getDatabase();
    for (final s in list) {
      final idVal = s['id'] ?? s['uuid'] ?? s['ID'];
      final name = s['name'] ?? s['agrochemical_name'] ?? s['agrochemicalName'] ?? '';
      final entry = <String, dynamic>{
        'id': idVal,
        'agrochemical_name': name,
      };
      try {
        await db.insert('agrochemical', entry, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (e) {
        print('⚠️ saveAgrochemicalList: failed to insert $entry: $e');
      }
    }
  }

  /// Replace tree_uuid for agrochemical rows when a locally-created tree
  /// receives a server UUID. This allows child records created while offline
  /// to be re-linked to the server tree before sync.
  Future<int> reassignTreeUuid(String oldUuid, String newUuid) async {
    final db = await LocalDB.getDatabase();
    return await db.update(
      'agrochemical_record',
      {'tree_uuid': newUuid},
      where: 'tree_uuid = ?',
      whereArgs: [oldUuid],
    );
  }

  // Return all agrochemical master/type rows from local DB
  Future<List<Map<String, dynamic>>> getAllAgrochemicals() async {
    final db = await LocalDB.getDatabase();
    try {
      final res = await db.query('agrochemical');
      return res;
    } catch (e) {
      print('⚠️ getAllAgrochemicals: failed to read agrochemical lookup: $e');
      return <Map<String, dynamic>>[];
    }
  }
}