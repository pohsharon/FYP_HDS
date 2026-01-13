import 'package:sqflite/sqflite.dart';
import 'local_db.dart';

class SpeciesDB{
  Future<void> saveSpeciesList(List<Map<String, dynamic>> speciesList) async {
    final db = await LocalDB.getDatabase();
    for (var s in speciesList) {
      final entry = <String, dynamic>{
        'id': s['id'],
        'code': s['code'] ?? s['species_code'] ?? '',
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
    final db = await LocalDB.getDatabase();
    return await db.query('species');
  }
}