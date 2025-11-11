import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/tree_model.dart';
import '../models/fruit_model.dart';

class LocalDB {
  static final LocalDB instance = LocalDB._init();
  static Database? _db;

  LocalDB._init();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB('farm_local.db');
    return _db!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Create tree table
    await db.execute('''
      CREATE TABLE trees(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT,
        tree_tag TEXT,
        species_id TEXT,
        planted_at TEXT,
        height REAL,
        diameter REAL,
        thumbnail TEXT,
        latitude REAL,
        longitude REAL,
        flowering_period INTEGER,
        synced INTEGER DEFAULT 0,
        pending_update INTEGER DEFAULT 0,
        pending_delete INTEGER DEFAULT 0
      )
    ''');

    // Create species table
    await db.execute('''
      CREATE TABLE species(
        id INTEGER PRIMARY KEY,
        name TEXT
      )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS fruits (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      harvest_uuid TEXT UNIQUE,
      transaction_uuid TEXT,
      harvested_at TEXT,
      is_spoiled INTEGER DEFAULT 0,
      tree_uuid TEXT,
      weight REAL,
      grade TEXT,
      synced INTEGER DEFAULT 0,
      pending_update INTEGER DEFAULT 0,
      pending_delete INTEGER DEFAULT 0
    )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'CREATE TABLE IF NOT EXISTS species(id INTEGER PRIMARY KEY, name TEXT)',
      );
      await db.execute(
        'ALTER TABLE trees ADD COLUMN pending_update INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE trees ADD COLUMN pending_delete INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE trees ADD COLUMN synced INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE species ADD COLUMN species_name TEXT');
    }
  }

  //Tree CRUD operations
  Future<int> insertTree(TreeModel tree) async {
    final db = await instance.database;
    final map = tree.toMap();
    final res = await db.insert(
      'trees',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return res;
  }

  Future<List<TreeModel>> fetchAllTrees() async {
    final db = await instance.database;
    final result = await db.query('trees');
    return result.map((e) => TreeModel.fromMap(e)).toList();
  }

  Future<List<TreeModel>> fetchUnsyncedTrees() async {
    final db = await instance.database;
    final result = await db.query('trees', where: 'synced = ?', whereArgs: [0]);
    return result.map((e) => TreeModel.fromMap(e)).toList();
  }

  Future<int> markAsSynced(String uuid) async {
    final db = await instance.database;
    final updated = await db.update(
      'trees',
      {'synced': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return updated;
  }

  Future<int> markAsSyncedByTag(String treeTag) async {
    final db = await instance.database;
    final updated = await db.update(
      'trees',
      {'synced': 1},
      where: 'tree_tag = ?',
      whereArgs: [treeTag],
    );
    return updated;
  }

  Future<int> deleteAllTrees() async {
    final db = await instance.database;
    return await db.delete('trees');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  Future<void> saveSpeciesList(List<Map<String, dynamic>> speciesList) async {
    final db = await database;
    for (var s in speciesList) {
      final entry = <String, dynamic>{
        'id': s['id'],
        'name': s['name'] ?? s['title'] ?? s['label'] ?? s['value'] ?? '',
      };

      try {
        await db.insert(
          'species',
          entry,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e) {
        // Log but don't crash the caller — mismatch in schema is non-fatal for app flow.
        print('⚠️ saveSpeciesList: failed to insert species row $entry: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> getAllSpecies() async {
    final db = await database;
    return await db.query('species');
  }

  Future<void> cacheRemoteTrees(List<TreeModel> remoteTrees) async {
    final db = await instance.database;

    try {
      final beforeAll = await db.query('trees');
      print(
        '🔎 cacheRemoteTrees: total rows before caching: ${beforeAll.length}',
      );
      for (final r in beforeAll) {
        print(
          '   • row -> uuid=${r['uuid']}, tree_tag=${r['tree_tag']}, synced=${r['synced']}',
        );
      }
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

  Future <void> cacheRemoteFruits(List<FruitModel> remoteFruits) async {
    final db = await instance.database;

    try {
      final beforeAll = await db.query('fruits');
      print(
        '🔎 cacheRemoteFruits: total rows before caching: ${beforeAll.length}',
      );
      for (var r in beforeAll) {
        print(
          '   • row -> harvest_uuid=${r['harvest_uuid']}, tree_uuid=${r['tree_uuid']}, synced=${r['synced']}',
        );
      }
    } catch (e) {
      print('⚠️ cacheRemoteFruits: error dumping rows before caching: $e');
    }

    // Preserve rows that are unsynced (synced=0) OR have pending updates/deletes
    final unsyncedOrPending = await db.query(
      'fruits',
      where: '(synced = ? OR pending_update = ? OR pending_delete = ?)',
      whereArgs: [0, 1, 1],
    );
    print(
      '📦 Preserving ${unsyncedOrPending.length} local rows (unsynced or pending) before caching remote data',
    );
    if (unsyncedOrPending.isNotEmpty) {
      for (final u in unsyncedOrPending) {
        print(
          '   • preserving -> harvest_uuid=${u['harvest_uuid']}, tree_uuid=${u['tree_uuid']}, synced=${u['synced']}, pending_update=${u['pending_update']}, pending_delete=${u['pending_delete']}',
        );
      }
    }

    // Step 2: Delete only synced ones
    await db.delete('fruits', where: 'synced = ?', whereArgs: [1]);

    // Step 3: Insert remote fruits (marked as synced)
    print('📥 Inserting ${remoteFruits.length} remote fruits into local DB');
    final seen = <String>{};
    int genCounter = 0;
    for (var i = 0; i < remoteFruits.length; i++) {
      final fruit = remoteFruits[i];
      final fm = fruit.toMap();
      var hid = fm['harvest_uuid'] ?? fm['uuid'] ?? fm['id'] ?? '';

      // If server provides empty or duplicate harvest id, generate a stable
      // fallback id so we don't replace previous rows.
      if (hid == null) hid = '';
      if (hid.toString().trim().isEmpty || seen.contains(hid.toString())) {
        genCounter++;
        final generated = 'gen_${DateTime.now().millisecondsSinceEpoch}_${i}_$genCounter';
        print('   • remote fruit had empty/duplicate id. Generated id=$generated');
        hid = generated;
      }

      seen.add(hid.toString());
      print('   • remote fruit -> harvest_uuid=$hid');

      // Ensure the map contains the canonical harvest_uuid key for DB insertion
      final insertMap = Map<String, dynamic>.from(fm);
      insertMap['harvest_uuid'] = hid;
      insertMap['synced'] = 1;

      await db.insert('fruits', insertMap, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Step 4: Reinsert preserved local rows (unsynced or pending)
    for (final u in unsyncedOrPending) {
      await db.insert('fruits', u, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final total = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM fruits'),
    );
    print('✅ Local cache updated. Total fruits in DB: $total');
  }

  Future<int> markAsPendingUpdate(String uuid) async {
    final db = await database;
    return await db.update(
      'trees',
      {'pending_update': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<int> markAsPendingDelete(String uuid) async {
    final db = await database;
    return await db.update(
      'trees',
      {'pending_delete': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<List<TreeModel>> fetchPendingUpdates() async {
    final db = await database;
    final result = await db.query(
      'trees',
      where: 'pending_update = ?',
      whereArgs: [1],
    );
    return result.map((e) => TreeModel.fromMap(e)).toList();
  }

  Future<List<TreeModel>> fetchPendingDeletes() async {
    final db = await database;
    final result = await db.query(
      'trees',
      where: 'pending_delete = ?',
      whereArgs: [1],
    );
    return result.map((e) => TreeModel.fromMap(e)).toList();
  }

  Future<int> deleteTreeByUuid(String uuid) async {
    final db = await database;
    return await db.delete('trees', where: 'uuid = ?', whereArgs: [uuid]);
  }

  /// Update an existing tree row identified by uuid.
  /// If [markPendingUpdate] is true, sets `pending_update` to 1 so sync will upload this change.
  Future<int> updateTreeByUuid(
    String uuid,
    Map<String, dynamic> changes, {
    bool markPendingUpdate = false,
  }) async {
    final db = await database;
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
    final db = await database;
    return await db.update(
      'trees',
      {'pending_update': 0, 'synced': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<int> insertFruit(FruitModel fruit) async {
  final db = await instance.database;
  return await db.insert('fruits', fruit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace);
}

Future<List<FruitModel>> getAllFruits() async {
  final db = await instance.database;
  final result = await db.query('fruits');
  return result.map((json) => FruitModel.fromMap(json)).toList();
}

Future<int> updateFruit(FruitModel fruit) async {
  final db = await instance.database;
  return await db.update('fruits', fruit.toMap(),
      where: 'harvest_uuid = ?', whereArgs: [fruit.harvest_uuid]);
}

Future<void> markFruitAsSynced(String uuid) async {
  final db = await instance.database;
  await db.update('fruits', {'synced': 1},
      where: 'harvest_uuid = ?', whereArgs: [uuid]);
}

Future<List<FruitModel>> getUnsyncedFruits() async {
  final db = await instance.database;
  final result = await db.query('fruits', where: 'synced = ?', whereArgs: [0]);
  return result.map((json) => FruitModel.fromMap(json)).toList();
}

  // Fruit pending helpers
  Future<int> markFruitAsPendingUpdate(String harvestUuid) async {
    final db = await instance.database;
    return await db.update(
      'fruits',
      {'pending_update': 1},
      where: 'harvest_uuid = ?',
      whereArgs: [harvestUuid],
    );
  }

  Future<int> markFruitAsPendingDelete(String harvestUuid) async {
    final db = await instance.database;
    return await db.update(
      'fruits',
      {'pending_delete': 1},
      where: 'harvest_uuid = ?',
      whereArgs: [harvestUuid],
    );
  }

  Future<List<FruitModel>> fetchPendingFruitUpdates() async {
    final db = await instance.database;
    final result = await db.query('fruits', where: 'pending_update = ?', whereArgs: [1]);
    return result.map((json) => FruitModel.fromMap(json)).toList();
  }

  Future<List<FruitModel>> fetchPendingFruitDeletes() async {
    final db = await instance.database;
    final result = await db.query('fruits', where: 'pending_delete = ?', whereArgs: [1]);
    return result.map((json) => FruitModel.fromMap(json)).toList();
  }

  Future<int> deleteFruitByHarvestUuid(String harvestUuid) async {
    final db = await instance.database;
    return await db.delete('fruits', where: 'harvest_uuid = ?', whereArgs: [harvestUuid]);
  }

  Future<int> clearFruitPendingUpdate(String harvestUuid) async {
    final db = await instance.database;
    return await db.update('fruits', {'pending_update': 0, 'synced': 1}, where: 'harvest_uuid = ?', whereArgs: [harvestUuid]);
  }



  // Future<void> resetTreesTable() async {
  //   final db = await instance.database;
  //   // Drop the old table if it exists
  //   await db.execute('DROP TABLE IF EXISTS trees');

  //   // Recreate it with the correct columns
  //   await db.execute('''
  //     CREATE TABLE trees (
  //       id INTEGER PRIMARY KEY AUTOINCREMENT,
  //       uuid TEXT,
  //       tree_tag TEXT,
  //       species_id INTEGER,
  //       planted_at TEXT,
  //       height REAL,
  //       diameter REAL,
  //       flowering_period TEXT,
  //       thumbnail TEXT,
  //       latitude REAL,
  //       longitude REAL,
  //       synced INTEGER DEFAULT 1,
  //       pending_update INTEGER DEFAULT 0,
  //       pending_delete INTEGER DEFAULT 0
  //     )
  //   ''');
  //   print('✅ Trees table reset successfully');
  // }

  // Future<void> resetTreesTable() async {
  //   final db = await instance.database;
  //   // Drop the old table if it exists
  //   await db.execute('DROP TABLE IF EXISTS species');

  //   // Recreate it with the correct columns
  //   await db.execute('''
  //     CREATE TABLE species(
  //         id INTEGER PRIMARY KEY,
  //         name TEXT
  //       )
  //   ''');
  //   print('✅ Species table reset successfully');
  // }
}
