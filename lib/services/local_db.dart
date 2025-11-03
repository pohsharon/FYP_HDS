import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/tree_model.dart';

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
    return await openDatabase(path, version: 2, onCreate: _createDB, onUpgrade: _upgradeDB);
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
        synced INTEGER DEFAULT 0
      )
    ''');

    // ✅ Create species table
    await db.execute('''
      CREATE TABLE species(
        id INTEGER PRIMARY KEY,
        name TEXT
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('CREATE TABLE IF NOT EXISTS species(id INTEGER PRIMARY KEY, name TEXT)');
    }
  }

  // ======================
  // CRUD OPERATIONS
  // ======================

  Future<int> insertTree(TreeModel tree) async {
    final db = await instance.database;
    final map = tree.toMap();
    final res = await db.insert('trees', map, conflictAlgorithm: ConflictAlgorithm.replace);
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

  // ======================
  // Species Storage
  // ======================

  Future<void> saveSpeciesList(List<Map<String, dynamic>> speciesList) async {
    final db = await database;
    for (var s in speciesList) {
      await db.insert(
        'species',
        s,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getAllSpecies() async {
    final db = await database;
    return await db.query('species');
  }

  // ======================
  // 🌐 Cache Remote Trees (with preservation)
  // ======================

  Future<void> cacheRemoteTrees(List<TreeModel> remoteTrees) async {
    final db = await instance.database;

    // Step 1: Keep unsynced trees
    final unsynced = await db.query('trees', where: 'synced = ?', whereArgs: [0]);
    print('📦 Preserving ${unsynced.length} unsynced trees before caching remote data');

    // Step 2: Delete only synced ones
    await db.delete('trees', where: 'synced = ?', whereArgs: [1]);

    // Step 3: Insert remote trees (marked as synced)
    for (final tree in remoteTrees) {
      await db.insert(
        'trees',
        {
          ...tree.toMap(),
          'synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Step 4: Reinsert unsynced ones
    for (final u in unsynced) {
      await db.insert('trees', u, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final total = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM trees'));
    print('✅ Local cache updated. Total trees in DB: $total');
  }
}
