import 'package:sqflite/sqflite.dart';
import 'local_db.dart';

class DiseaseDB{
  Future<void> saveDiseaseList(List<Map<String, dynamic>> diseaseList) async {
    final db = await LocalDB.getDatabase();
    for (var s in diseaseList) {
      final entry = <String, dynamic>{
        'id': s['id'],
        'disease_name': s['disease_name'],
        'symptoms': s['symptoms'],  
        'remarks': s['remarks'],
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
    return await db.query('diseases');
  }
}