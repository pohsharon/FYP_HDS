import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDB {
  static final LocalDB instance = LocalDB._init();
  static Database? _db;
  static const int _targetDbVersion = 1;

  LocalDB._init();

   static Future<Database> getDatabase() async {
    if (_db != null) {
      return _db!;
    }

    _db = await openDatabase(
      join(await getDatabasesPath(), 'durian_farm.db'),
      version: _targetDbVersion,
      onCreate: (db, version) async {
        await _createDB(db);
      },
    );

    return _db!;
  }

  static Future _createDB(Database db) async {
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
        updated_at TEXT,
        synced INTEGER DEFAULT 0,
        pending_update INTEGER DEFAULT 0,
        pending_delete INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE species(
        id INTEGER PRIMARY KEY,
        code TEXT,
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
        disease_name TEXT,
        thumbnail TEXT,
        synced INTEGER DEFAULT 0,
        pending_update INTEGER DEFAULT 0,
        pending_delete INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS diseases (
        id INTEGER PRIMARY KEY,
        disease_name TEXT,
        symptoms TEXT,
        remarks TEXT
      )
    ''');

    // Agrochemical lookup table (optional metadata)
    await db.execute('''
    CREATE TABLE IF NOT EXISTS agrochemical (
        id TEXT PRIMARY KEY,
        agrochemical_name TEXT
      )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS agrochemical_record (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        agrochemical_name TEXT,
        tree_uuid TEXT,
        agrochemicalId TEXT,
        applied_at TEXT,
        description TEXT,
        synced INTEGER DEFAULT 0,
        pending_update INTEGER DEFAULT 0,
        pending_delete INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS harvest_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        event_name TEXT,
        start_date TEXT,
        end_date TEXT,
        synced INTEGER DEFAULT 1
      )
    ''');
  }
}
