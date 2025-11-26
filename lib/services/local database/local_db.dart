import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/tree_model.dart';
import '../../models/fruit_model.dart';
import '../../models/tree_growth_model.dart';

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
      version: 4,
      onCreate: _createDB,
      // onUpgrade: _upgradeDB,
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

    await db.execute('''
      CREATE TABLE species(
        id INTEGER PRIMARY KEY,
        name TEXT
      )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS fruits (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      fruit_tag TEXT,
      harvest_uuid TEXT UNIQUE,
      transaction_uuid TEXT,
      harvested_at TEXT,
      created_at TEXT,
      is_spoiled INTEGER DEFAULT 0,
      tree_uuid TEXT,
      weight REAL,
      grade TEXT,
      synced INTEGER DEFAULT 0,
      pending_update INTEGER DEFAULT 0,
      pending_delete INTEGER DEFAULT 0
    )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS tree_growth (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT,
        tree_uuid TEXT,
        height REAL,
        diameter REAL,
        notes TEXT,
        created_at TEXT,
        synced INTEGER DEFAULT 0,
        pending_update INTEGER DEFAULT 0,
        pending_delete INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS health_record (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tree_uuid TEXT,
        diseaseId TEXT,
        status TEXT,
        recorded_at TEXT,
        treatment TEXT,
        synced INTEGER DEFAULT 0,
        pending_update INTEGER DEFAULT 0,
        pending_delete INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS disease (
        id INTEGER PRIMARY KEY,
        diease_name TEXT,
        symptoms TEXT,
        remarks TEXT
      )
    ''');
  }

  // Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
  //   if (oldVersion < 3) {
  //     await db.execute(
  //       'CREATE TABLE IF NOT EXISTS species(id INTEGER PRIMARY KEY, name TEXT)',
  //     );
  //     await db.execute(
  //       'ALTER TABLE trees ADD COLUMN pending_update INTEGER DEFAULT 0',
  //     );
  //     await db.execute(
  //       'ALTER TABLE trees ADD COLUMN pending_delete INTEGER DEFAULT 0',
  //     );
  //     await db.execute('ALTER TABLE trees ADD COLUMN synced INTEGER DEFAULT 0');
  //     await db.execute('ALTER TABLE species ADD COLUMN species_name TEXT');
  //   }
  //   if (oldVersion < 3) {
  //     // Add fruit_tag column to fruits table for storing server-provided fruit tags
  //     try {
  //       await db.execute('ALTER TABLE fruits ADD COLUMN fruit_tag TEXT');
  //     } catch (e) {
  //       print('⚠️ upgradeDB: could not add fruit_tag column: $e');
  //     }
  //   }
  //   if (oldVersion < 4) {
  //     // Add created_at column for ordering and sync clarity
  //     try {
  //       await db.execute('ALTER TABLE fruits ADD COLUMN created_at TEXT');
  //       print('✅ upgradeDB: added created_at to fruits');
  //     } catch (e) {
  //       print('⚠️ upgradeDB: could not add created_at column: $e');
  //     }
  //   }
  // }

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

  Future<void> cacheRemoteFruits(List<FruitModel> remoteFruits) async {
    final db = await instance.database;

    try {
      final beforeAll = await db.query('fruits');
      print('ℹ️ cacheRemoteFruits: rows before caching=${beforeAll.length}');
    } catch (e) {
      print('⚠️ cacheRemoteFruits: error dumping rows before caching: $e');
    }

    final unsyncedOrPending = await db.query(
      'fruits',
      where: '(synced = ? OR pending_update = ? OR pending_delete = ?)',
      whereArgs: [0, 1, 1],
    );

    // Step 2: Delete only synced ones
    await db.delete('fruits', where: 'synced = ?', whereArgs: [1]);
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
    return await db.insert(
      'fruits',
      fruit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<FruitModel>> getAllFruits() async {
    final db = await instance.database;
    // Order: unsynced (0) first, then by created_at descending so newly created
    // local items appear at the top.
    final result = await db.query(
      'fruits',
      orderBy: 'synced ASC, created_at DESC',
    );
    return result.map((json) => FruitModel.fromMap(json)).toList();
  }

  Future<int> updateFruit(FruitModel fruit) async {
    final db = await instance.database;
    return await db.update(
      'fruits',
      fruit.toMap(),
      where: 'harvest_uuid = ?',
      whereArgs: [fruit.harvest_uuid],
    );
  }

  Future<void> markFruitAsSynced(String uuid) async {
    final db = await instance.database;
    await db.update(
      'fruits',
      {'synced': 1},
      where: 'harvest_uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<List<FruitModel>> getUnsyncedFruits() async {
    final db = await instance.database;
    final result = await db.query(
      'fruits',
      where: 'synced = ?',
      whereArgs: [0],
    );
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
    final result = await db.query(
      'fruits',
      where: 'pending_update = ?',
      whereArgs: [1],
    );
    return result.map((json) => FruitModel.fromMap(json)).toList();
  }

  Future<List<FruitModel>> fetchPendingFruitDeletes() async {
    final db = await instance.database;
    final result = await db.query(
      'fruits',
      where: 'pending_delete = ?',
      whereArgs: [1],
    );
    return result.map((json) => FruitModel.fromMap(json)).toList();
  }

  Future<int> deleteFruitByHarvestUuid(String harvestUuid) async {
    final db = await instance.database;
    return await db.delete(
      'fruits',
      where: 'harvest_uuid = ?',
      whereArgs: [harvestUuid],
    );
  }

  Future<int> clearFruitPendingUpdate(String harvestUuid) async {
    final db = await instance.database;
    return await db.update(
      'fruits',
      {'pending_update': 0, 'synced': 1},
      where: 'harvest_uuid = ?',
      whereArgs: [harvestUuid],
    );
  }

  Future<int> insertGrowth(TreeGrowthModel g) async {
    final db = await database;
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
    final db = await database;
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
    final db = await database;
    final result = await db.query(
      'tree_growth',
      where: 'synced = ?',
      whereArgs: [0],
    );
    return result.map((r) => TreeGrowthModel.fromMap(r)).toList();
  }

  Future<int> markGrowthAsSynced(String uuid) async {
    final db = await database;
    return await db.update(
      'tree_growth',
      {'synced': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<int> markGrowthAsPendingUpdate(String uuid) async {
    final db = await database;
    return await db.update(
      'tree_growth',
      {'pending_update': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<int> markGrowthAsPendingDelete(String uuid) async {
    final db = await database;
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
    final db = await database;
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
    final db = await database;
    return await db.delete('tree_growth', where: 'uuid = ?', whereArgs: [uuid]);
  }

  Future<int> deleteAllGrowths() async {
    final db = await database;
    return await db.delete('tree_growth');
  }

  Future<void> cacheRemoteGrowths(List<TreeGrowthModel> remote) async {
    final db = await database;

    try {
      final before = await db.query('tree_growth');
      print('ℹ️ cacheRemoteGrowths: rows before caching=${before.length}');
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
      print(
        'ℹ️ cacheRemoteGrowths: remote batch empty — skipping delete/insert to preserve local cache',
      );
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
    print('✅ Cached remote growths. Total growth rows: $total');
  }
}
