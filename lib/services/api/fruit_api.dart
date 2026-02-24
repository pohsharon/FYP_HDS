// import 'dart:convert';
// import 'package:http/http.dart' as http;
// // Fruit API removed/replaced
// // The original fruit-related network methods have been replaced with stubs
// // so the feature can be reimplemented later. Callers will receive empty
// // responses or no-ops.

// class FruitApi {
//   /// Stub: createFruit — returns an empty map
//   static Future<Map<String, dynamic>> createFruit({
//     required String tree_uuid,
//     required String harvest_uuid,
//     required double weight,
//     required String grade,
//     required String harvested_at,
//     required dynamic is_spoiled,
//   }) async {
//     return <String, dynamic>{'message': 'Fruit API removed'};
//   }

//   /// Stub: fetchFruits — returns empty list
//   static Future<List<Map<String, dynamic>>> fetchFruits() async {
//     return <Map<String, dynamic>>[];
//   }

//   /// Stub: fetchFruitsByHarvestUuid — returns empty list
//   static Future<List<Map<String, dynamic>>> fetchFruitsByHarvestUuid(
//       String harvestUuid) async {
//     return <Map<String, dynamic>>[];
//   }

//   /// Stub: updateFruit — no-op
//   static Future<void> updateFruit({
//     required String uuid,
//     required String tree_uuid,
//     required String harvest_uuid,
//     required double weight,
//     required String grade,
//     required String harvested_at,
//     required dynamic is_spoiled,
//   }) async {
//     return;
//   }

//   /// Stub: deleteFruit — no-op
//   static Future<void> deleteFruit(String uuid) async {
//     return;
//   }
// }
//     );

//     if (response.statusCode == 200) {
//       return;
//     }

//     if (response.body.trim().isNotEmpty) {
//       try {
//         final data = jsonDecode(response.body);
//         throw Exception(data["message"] ?? "Failed to delete fruit");
//       } catch (e) {
//         throw Exception("Unexpected error: ${response.body}");
//       }
//     }

//     throw Exception("Failed to delete tree (No response body)");
//   }
// }
