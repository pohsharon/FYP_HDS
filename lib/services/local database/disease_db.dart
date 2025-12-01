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
        'disease_name': diseaseName,
        'symptoms': symptoms,
        'remarks': remarks,
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