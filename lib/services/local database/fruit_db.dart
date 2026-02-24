// FruitDB methods replaced with lightweight stubs while fruit feature is removed.
// These stubs preserve the API surface so callers will not break, but they
// return empty results / no-ops. Reimplement when restoring fruit functionality.

class FruitDB {
  Future<int> insertFruit(dynamic fruit) async => 0;
  Future<List<dynamic>> getAllFruits() async => <dynamic>[];
  Future<List<dynamic>> fetchFruitsByTree(String treeUuid) async => <dynamic>[];
  Future<int> updateFruit(dynamic fruit) async => 0;
  Future<void> markFruitAsSynced(String uuid) async {}
  Future<List<dynamic>> getUnsyncedFruits() async => <dynamic>[];
  Future<int> markFruitAsPendingUpdate(String harvestUuid) async => 0;
  Future<int> markFruitAsPendingDelete(String harvestUuid) async => 0;
  Future<List<dynamic>> fetchPendingFruitUpdates() async => <dynamic>[];
  Future<List<dynamic>> fetchPendingFruitDeletes() async => <dynamic>[];
  Future<int> deleteFruitByHarvestUuid(String harvestUuid) async => 0;
  Future<int> clearFruitPendingUpdate(String harvestUuid) async => 0;
  Future<void> cacheRemoteFruits(List<dynamic> remoteFruits) async {}
  Future<int> reassignTreeUuid(String oldUuid, String newUuid) async => 0;
  Future<int> reassignFruitUuid(String oldUuid, String newUuid) async => 0;
  Future<int> updateFruitUuid(String harvestUuid, String serverUuid) async => 0;
  Future<String> getNextFruitTag() async => 'FR000001';
}