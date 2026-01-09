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
    int insertedCount = 0;
    
    for (var i = 0; i < remoteFruits.length; i++) {
      final fruit = remoteFruits[i];
      final fm = fruit.toMap();
      
      // The cloud database has:
      // - uuid: the fruit's own ID
      // - harvest_uuid: the harvest event UUID it belongs to
      var fruitUuid = fm['uuid'] ?? fm['id'] ?? '';
      var harvestUuid = fm['harvest_uuid'] ?? '';
      
      fruitUuid ??= '';
      harvestUuid ??= '';
      
      if (fruitUuid.toString().trim().isEmpty) {
        print('⚠️ Skipping fruit with no UUID at index $i');
        continue;
      }

      if (seen.contains(fruitUuid.toString())) {
        print('⚠️ Skipping duplicate fruit UUID: $fruitUuid');
        continue;
      }

      seen.add(fruitUuid.toString());

      // Keep both uuid (fruit ID) and harvest_uuid (event ID) separate as they are in cloud
      final insertMap = Map<String, dynamic>.from(fm);
      insertMap['uuid'] = fruitUuid;  // Fruit's own ID
      insertMap['harvest_uuid'] = harvestUuid;  // The harvest event UUID it belongs to
      insertMap['synced'] = 1;
      insertMap['pending_update'] = 0;
      insertMap['pending_delete'] = 0;

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
          final idStr = fruitUuid.toString();
          derived = idStr.length > 8 ? idStr.substring(0, 8) : idStr;
        }
        insertMap['fruit_tag'] = derived;
      }

      // Ensure created_at is present so we can order items reliably.
      if (insertMap['created_at'] == null ||
          insertMap['created_at'].toString().trim().isEmpty) {
        insertMap['created_at'] = DateTime.now().toIso8601String();
      }
      
      try {
        await db.insert(
          'fruits',
          insertMap,
          conflictAlgorithm: ConflictAlgorithm.replace,  // Use REPLACE to ensure it goes in
        );
        insertedCount++;
      } catch (e) {
        print('❌ Failed to insert fruit $fruitUuid: $e');
      }
    }

    // Step 4: Reinsert preserved local rows (unsynced or pending)
    for (final u in unsyncedOrPending) {
      try {
        await db.insert(
          'fruits',
          u,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e) {
        print('❌ Failed to reinsert local fruit: $e');
      }
    }
    
    // Verify final count
    final finalCount = await db.query('fruits');
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

  /// Reassign a fruit's harvest_uuid from offline-generated (gen_*) to server UUID.
  /// This is used when a fruit created offline receives an authoritative UUID from the server.
  Future<int> reassignFruitUuid(String oldUuid, String newUuid) async {
    final db = await LocalDB.getDatabase();
    return await db.update(
      'fruits',
      {'harvest_uuid': newUuid, 'uuid': newUuid},
      where: 'harvest_uuid = ?',
      whereArgs: [oldUuid],
    );
  }

  /// Update the uuid field for a fruit (called after sync to store server UUID)
  Future<int> updateFruitUuid(String harvestUuid, String serverUuid) async {
    final db = await LocalDB.getDatabase();
    return await db.update(
      'fruits',
      {'uuid': serverUuid},
      where: 'harvest_uuid = ?',
      whereArgs: [harvestUuid],
    );
  }

  /// Generate the next fruit tag in format FRXXXXXX (FR + 6 digits)
  /// Scans all fruit_tags and finds the highest number, returns the next one
  Future<String> getNextFruitTag() async {
    final db = await LocalDB.getDatabase();
    final result = await db.query('fruits', columns: ['fruit_tag']);
    
    int maxNumber = 0;
    for (final row in result) {
      final tag = row['fruit_tag']?.toString() ?? '';
      // Try to extract number from FRXXXXXX format
      if (tag.startsWith('FR') && tag.length == 8) {
        try {
          final numStr = tag.replaceFirst('FR', '');
          final num = int.tryParse(numStr) ?? 0;
          if (num > maxNumber) {
            maxNumber = num;
          }
        } catch (_) {}
      }
    }
    
    // Return next number in format FRXXXXXX (6 digits padded with zeros)
    final nextNumber = maxNumber + 1;
    return 'FR${nextNumber.toString().padLeft(6, '0')}';
  }

}