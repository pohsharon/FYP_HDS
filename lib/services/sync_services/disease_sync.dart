import '../local database/disease_db.dart';
import '../api/disease_api.dart';

class SyncDiseases {
  Future<void> syncDiseases() async {
    try {
      final db = DiseaseDB();
      
      // 1) Handle pending deletes
      final deletes = await db.fetchPendingDeletes();
      for (final d in deletes) {
        try {
          final id = d['uuid']?.toString() ?? d['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          
          await DiseaseApi.deleteDisease(id);
          await db.deleteDisease(id);
          print('✅ Deleted disease: $id');
        } catch (e) {
          print('⚠️ Failed to delete disease: $e');
        }
      }
      
      // 2) Handle pending updates
      final updates = await db.fetchPendingUpdates();
      for (final d in updates) {
        try {
          final id = d['uuid']?.toString() ?? d['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          
          await DiseaseApi.updateDisease(
            id: id,
            diseaseName: d['disease_name']?.toString() ?? '',
            symptoms: d['symptoms']?.toString() ?? '',
            remarks: d['remarks']?.toString() ?? '',
          );
          await db.markAsSynced(id);
          print('✅ Synced disease update: $id');
        } catch (e) {
          print('⚠️ Failed to sync disease update: $e');
        }
      }
      
      // 3) Handle unsynced new diseases
      final unsynced = await db.fetchUnsyncedDiseases();
      for (final d in unsynced) {
        try {
          await DiseaseApi.createDisease(
            diseaseName: d['disease_name']?.toString() ?? '',
            symptoms: d['symptoms']?.toString() ?? '',
            remarks: d['remarks']?.toString() ?? '',
          );
          
          final uuid = d['uuid']?.toString() ?? '';
          if (uuid.isNotEmpty) {
            await db.markAsSynced(uuid);
          }
          print('✅ Synced new disease: ${d['disease_name']}');
        } catch (e) {
          print('⚠️ Failed to sync new disease: $e');
        }
      }
    } catch (e) {
      print('⚠️ Disease sync error: $e');
    }
  }
}
