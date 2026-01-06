import 'package:sqflite/sqflite.dart';
import 'local_db.dart';

class DiseaseDB{
  Future<void> saveDiseaseList(List<Map<String, dynamic>> diseaseList) async {
    final db = await LocalDB.getDatabase();
    for (var s in diseaseList) {
      // Normalize possible key names from different API shapes (camelCase vs snake_case)
      final idVal = s['id'] ?? s['uuid'] ?? s['ID'];
      final diseaseName = s['diseaseName'] ?? s['disease_name'] ?? s['name'] ?? '';
      final symptoms = s['symptoms'] ?? s['symptom'] ?? '';
      final remarks = s['remarks'] ?? s['note'] ?? s['notes'] ?? '';

      final entry = <String, dynamic>{
        'id': idVal,
        'uuid': s['uuid']?.toString(),
        'disease_name': diseaseName,
        'symptoms': symptoms,
        'remarks': remarks,
        'synced': 1,
        'pending_update': 0,
        'pending_delete': 0,
      };

      try {
        await db.insert(
          'diseases',
          entry,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e) {
        print('⚠️ saveDiseaseList: failed to insert disease row $entry: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> getAllDiseases() async {
    final db = await LocalDB.getDatabase();
    final result = await db.query(
      'diseases',
      where: 'pending_delete = ?',
      whereArgs: [0],
    );
    return result;
  }

  Future<int> insertDisease(Map<String, dynamic> disease) async {
    final db = await LocalDB.getDatabase();
    return await db.insert(
      'diseases',
      disease,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateDisease(String uuid, Map<String, dynamic> changes) async {
    final db = await LocalDB.getDatabase();
    return await db.update(
      'diseases',
      changes,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<int> deleteDisease(String uuid) async {
    final db = await LocalDB.getDatabase();
    return await db.delete(
      'diseases',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<int> markAsPendingDelete(String uuid) async {
    final db = await LocalDB.getDatabase();
    return await db.update(
      'diseases',
      {'pending_delete': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<List<Map<String, dynamic>>> fetchUnsyncedDiseases() async {
    final db = await LocalDB.getDatabase();
    return await db.query(
      'diseases',
      where: 'synced = ?',
      whereArgs: [0],
    );
  }

  Future<List<Map<String, dynamic>>> fetchPendingUpdates() async {
    final db = await LocalDB.getDatabase();
    return await db.query(
      'diseases',
      where: 'pending_update = ?',
      whereArgs: [1],
    );
  }

  Future<List<Map<String, dynamic>>> fetchPendingDeletes() async {
    final db = await LocalDB.getDatabase();
    return await db.query(
      'diseases',
      where: 'pending_delete = ?',
      whereArgs: [1],
    );
  }

  Future<int> markAsSynced(String uuid) async {
    final db = await LocalDB.getDatabase();
    return await db.update(
      'diseases',
      {'synced': 1, 'pending_update': 0},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }
}