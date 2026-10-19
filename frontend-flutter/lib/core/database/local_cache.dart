import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalCache {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'gps_camioneiro_pro.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE route_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            origin_lat REAL,
            origin_lon REAL,
            dest_lat REAL,
            dest_lon REAL,
            route_json TEXT,
            created_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE alerts_cache (
            id TEXT PRIMARY KEY,
            type TEXT,
            message TEXT,
            latitude REAL,
            longitude REAL,
            timestamp INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE chat_cache (
            id TEXT PRIMARY KEY,
            driver_name TEXT,
            message TEXT,
            latitude REAL,
            longitude REAL,
            timestamp INTEGER
          )
        ''');
      },
    );
  }

  static Future<void> saveAlertCache(Map<String, dynamic> alert) async {
    final db = await database;
    await db.insert(
      'alerts_cache',
      {
        'id': alert['id'] ?? '',
        'type': alert['type'] ?? '',
        'message': alert['message'] ?? '',
        'latitude': alert['latitude'] ?? 0,
        'longitude': alert['longitude'] ?? 0,
        'timestamp': alert['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> saveChatCache(Map<String, dynamic> msg) async {
    final db = await database;
    await db.insert(
      'chat_cache',
      {
        'id': msg['id'] ?? '',
        'driver_name': msg['driver_name'] ?? '',
        'message': msg['message'] ?? '',
        'latitude': msg['latitude'] ?? 0,
        'longitude': msg['longitude'] ?? 0,
        'timestamp': msg['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> getCachedAlerts() async {
    final db = await database;
    return await db.query('alerts_cache', orderBy: 'timestamp DESC');
  }

  static Future<List<Map<String, dynamic>>> getCachedChat() async {
    final db = await database;
    return await db.query('chat_cache', orderBy: 'timestamp DESC');
  }

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('alerts_cache');
    await db.delete('chat_cache');
    await db.delete('route_cache');
  }
}
