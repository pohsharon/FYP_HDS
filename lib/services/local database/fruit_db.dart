import 'package:sqflite/sqflite.dart';
import 'local_db.dart';
import '../../models/fruit_model.dart';

class FruitDB{
  Future<int> insertFruit(FruitModel fruit) async {
    final db = await LocalDB.getDatabase();
    return await db.insert(
      'fruits',
      fruit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<FruitModel>> getAllFruits() async {
    final db = await LocalDB.getDatabase();
    final result = await db.query(
      'fruits',
      orderBy: 'synced ASC, created_at DESC',
    );
    return result.map((json) => FruitModel.fromMap(json)).toList();
  }

  /// Fetch fruits belonging to a specific tree UUID.
  Future<List<FruitModel>> fetchFruitsByTree(String treeUuid) async {
    final db = await LocalDB.getDatabase();
    final result = await db.query(
      'fruits',
      where: 'tree_uuid = ?',
      whereArgs: [treeUuid],
      orderBy: 'synced ASC, created_at DESC',
    );
    return result.map((json) => FruitModel.fromMap(json)).toList();
  }

  Future<int> updateFruit(FruitModel fruit) async {
    final db = await LocalDB.getDatabase();
    return await db.update(
      'fruits',
      fruit.toMap(),
      where: 'harvest_uuid = ?',
      whereArgs: [fruit.harvest_uuid],
    );
  }

  Future<void> markFruitAsSynced(String uuid) async {
    final db = await LocalDB.getDatabase();
    await db.update(
      'fruits',
      {'synced': 1},
      where: 'harvest_uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<List<FruitModel>> getUnsyncedFruits() async {
    final db = await LocalDB.getDatabase();
    final result = await db.query(
      'fruits',
      where: 'synced = ?',
      whereArgs: [0],
    );
    return result.map((json) => FruitModel.fromMap(json)).toList();
  }

  // Fruit pending helpers
  Future<int> markFruitAsPendingUpdate(String harvestUuid) async {
    final db = await LocalDB.getDatabase();
    return await db.update(
      'fruits',
      {'pending_update': 1},
      where: 'harvest_uuid = ?',
      whereArgs: [harvestUuid],
    );
  }

  Future<int> markFruitAsPendingDelete(String harvestUuid) async {
    final db = await LocalDB.getDatabase();
    return await db.update(
      'fruits',
      {'pending_delete': 1},
      where: 'harvest_uuid = ?',
      whereArgs: [harvestUuid],
    );
  }

  Future<List<FruitModel>> fetchPendingFruitUpdates() async {
    final db = await LocalDB.getDatabase();
    final result = await db.query(
      'fruits',
      where: 'pending_update = ?',
      whereArgs: [1],
    );
    return result.map((json) => FruitModel.fromMap(json)).toList();
  }

  Future<List<FruitModel>> fetchPendingFruitDeletes() async {
    final db = await LocalDB.getDatabase();
    final result = await db.query(
      'fruits',
      where: 'pending_delete = ?',
      whereArgs: [1],
    );
    return result.map((json) => FruitModel.fromMap(json)).toList();
  }

  Future<int> deleteFruitByHarvestUuid(String harvestUuid) async {
    final db = await LocalDB.getDatabase();
    return await db.delete(
      'fruits',
      where: 'harvest_uuid = ?',
      whereArgs: [harvestUuid],
    );
  }

  Future<int> clearFruitPendingUpdate(String harvestUuid) async {
    final db = await LocalDB.getDatabase();
    return await db.update(
      'fruits',
      {'pending_update': 0, 'synced': 1},
      where: 'harvest_uuid = ?',
      whereArgs: [harvestUuid],
    );
  }

  Future<void> cacheRemoteFruits(List<FruitModel> remoteFruits) async {
    final db = await LocalDB.getDatabase();

    try {
      await db.query('fruits');
    } catch (_) {}

    final unsyncedOrPending = await db.query(
      'fruits',
      where: '(synced = ? OR pending_update = ? OR pending_delete = ?)',
      whereArgs: [0, 1, 1],
    );

    // Step 2: Delete only synced ones
    await db.delete('fruits', where: 'synced = ?', whereArgs: [1]);
    final seen = <String>{};
    int genCounter = 0;
    for (var i = 0; i < remoteFruits.length; i++) {
      final fruit = remoteFruits[i];
      final fm = fruit.toMap();
      var hid = fm['harvest_uuid'] ?? fm['uuid'] ?? fm['id'] ?? '';

      // If server provides empty or duplicate harvest id, generate a stable
      // fallback id so we don't replace previous rows.
      hid ??= '';
      if (hid.toString().trim().isEmpty || seen.contains(hid.toString())) {
        genCounter++;
        final generated =
            'gen_${DateTime.now().millisecondsSinceEpoch}_${i}_$genCounter';
        hid = generated;
      }

      seen.add(hid.toString());

      // Ensure the map contains the canonical harvest_uuid key for DB insertion
      final insertMap = Map<String, dynamic>.from(fm);
      insertMap['harvest_uuid'] = hid;
      insertMap['synced'] = 1;

      // Prefer server-provided fruit_tag if present; otherwise derive a friendly tag
      if (insertMap['fruit_tag'] == null ||
          insertMap['fruit_tag'].toString().trim().isEmpty) {
        String derived;
        if (insertMap['grade'] != null &&
            insertMap['grade'].toString().isNotEmpty) {
          derived = 'Grade ${insertMap['grade']}';
        } else if (insertMap['harvested_at'] != null &&
            insertMap['harvested_at'].toString().isNotEmpty) {
          derived = insertMap['harvested_at'].toString();
        } else {
          final idStr = hid.toString();
          derived = idStr.length > 8 ? idStr.substring(0, 8) : idStr;
        }
        insertMap['fruit_tag'] = derived;
      }

      // Ensure created_at is present so we can order items reliably.
      if (insertMap['created_at'] == null ||
          insertMap['created_at'].toString().trim().isEmpty) {
        insertMap['created_at'] = DateTime.now().toIso8601String();
      }
            await db.insert(
        'fruits',
        insertMap,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // Step 4: Reinsert preserved local rows (unsynced or pending)
    for (final u in unsyncedOrPending) {
      // Reinsert preserved local rows and ensure they overwrite any remote
      // row that might have been inserted with the same harvest_uuid.
      await db.insert(
        'fruits',
        u,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }


  }

  /// Reassign tree_uuid for local fruit rows when a locally-created tree
  /// receives a server UUID. This ensures fruit records created offline are
  /// linked to the correct server tree when syncing.
  Future<int> reassignTreeUuid(String oldUuid, String newUuid) async {
    final db = await LocalDB.getDatabase();
    return await db.update(
      'fruits',
      {'tree_uuid': newUuid},
      where: 'tree_uuid = ?',
      whereArgs: [oldUuid],
    );
  }

}