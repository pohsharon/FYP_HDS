import '../local database/agro_db.dart';
import '../api/agrochemical_api.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

bool _looksLikeUuid(String? s) {
  if (s == null) return false;
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  // If the string contains only digits (e.g. '3'), it's not a UUID.
  // The regex above checks the canonical 36-char UUID format.
  return uuidRegex.hasMatch(s);
}

class SyncAgro {
  Future<void> syncAgro() async {
  try {
      final hasInternet =
          await Connectivity().checkConnectivity() != ConnectivityResult.none;
      if (!hasInternet) {
        print('📴 Offline — agro sync postponed');
        return;
      }

      final db = AgroDB();

      // 1) Pending deletes
      final deletes = await db.fetchPendingDeletes();
      for (final a in deletes) {
        try {
          final tu = a.tree_uuid ?? '';
          if (tu.isEmpty) {
            print('⚠️ Pending delete has no tree_uuid; skipping');
            continue;
          }

          try {
            // Fetch remote agrochemical records for this tree and try to match by applied_at + agrochemicalId/name
            final remote = await AgrochemicalApi.fetchAgrochemicals(treeUuid: tu);
            Map<String, dynamic>? match;
            for (final r in remote) {
              final applied = (r['applied_at'] ?? r['appliedAt'])?.toString() ?? '';
              final aid = (r['agrochemical_id'] ?? r['agrochemicalId'] ?? r['agrochemical'])?.toString() ?? '';
              if (applied.isNotEmpty && applied == (a.applied_at ?? '')) {
                // also ensure agrochemical id/name matches when available
                if ((aid.isNotEmpty && aid == (a.agrochemicalId ?? '')) || (r['agrochemical'] is Map && (r['agrochemical']['name'] ?? '') == (a.agrochemicalName ?? ''))) {
                  match = r;
                  break;
                }
              }
            }

            if (match != null && (match['id'] != null || match['uuid'] != null)) {
              // Prefer an explicit UUID field. Some API responses may include numeric 'id'
              // which isn't valid for endpoints that expect UUIDs. Validate before using.
              final candUuid = (match['uuid'] ?? match['id'])?.toString();
              if (!_looksLikeUuid(candUuid)) {
                print('⚠️ Resolved remote id is not a UUID (value=$candUuid). Skipping delete for tree $tu to avoid backend type errors.');
              } else {
                final id = candUuid!;
                await AgrochemicalApi.deleteAgrochemicalRecord(id);
                await db.deleteAgrochemicalByTreeUuid(tu);
                print('✅ Deleted remote & local agrochemical records for tree $tu');
              }
            } else {
              print('ℹ️ Could not resolve remote id for pending delete on tree $tu; skipping');
            }
          } catch (e) {
            print('⚠️ Failed to process pending delete for tree $tu: $e');
          }
        } catch (e) {
          print('⚠️ Error during agrochemical delete: $e');
        }
      }

      // 2) Pending updates
      final updates = await db.fetchPendingUpdates();
      for (final a in updates) {
        try {
          final tu = a.tree_uuid ?? '';
          if (tu.isEmpty) {
            print('⚠️ Pending update has no tree_uuid; skipping');
            continue;
          }

          try {
            final remote = await AgrochemicalApi.fetchAgrochemicals(treeUuid: tu);
            Map<String, dynamic>? match;
            for (final r in remote) {
              final applied = (r['applied_at'] ?? r['appliedAt'])?.toString() ?? '';
              final aid = (r['agrochemical_id'] ?? r['agrochemicalId'] ?? r['agrochemical'])?.toString() ?? '';
              if (applied.isNotEmpty && applied == (a.applied_at ?? '')) {
                if ((aid.isNotEmpty && aid == (a.agrochemicalId ?? '')) || (r['agrochemical'] is Map && (r['agrochemical']['name'] ?? '') == (a.agrochemicalName ?? ''))) {
                  match = r;
                  break;
                }
              }
            }

            if (match != null && (match['id'] != null || match['uuid'] != null)) {
              final candUuid = (match['uuid'] ?? match['id'])?.toString();
              if (!_looksLikeUuid(candUuid)) {
                print('⚠️ Resolved remote id is not a UUID (value=$candUuid). Skipping update for tree $tu to avoid backend type errors.');
              } else {
                final id = candUuid!;
                try {
                  await AgrochemicalApi.updateAgrochemicalRecord(
                    record_uuid: id,
                    agrochemical_uuid: a.agrochemicalId ?? '',
                    tree_uuid: a.tree_uuid ?? '',
                    applied_at: a.applied_at ?? '',
                    description: a.description ?? '',
                  );
                  await db.markAsSynced(a.tree_uuid ?? '');
                  print('✅ Synced agrochemical update for tree ${a.tree_uuid}');
                } catch (e) {
                  print('❌ Agrochemical update failed for ${a.tree_uuid}: $e');
                }
              }
            } else {
              print('ℹ️ Could not resolve remote id for pending update on tree $tu; skipping');
            }
          } catch (e) {
            print('⚠️ Failed to resolve remote id for update for tree $tu: $e');
          }
        } catch (e) {
          print('⚠️ Error processing pending agrochemical update: $e');
        }
      }

      // 3) New unsynced health records
      final unsynced = await db.fetchUnsyncedAgrochemicals();
      final newOnes = unsynced.where((h) => h.pendingUpdate == 0 && h.pendingDelete == 0).toList();
      for (final h in newOnes) {
        try {
          // Ensure we send a server-valid agrochemical UUID. If the local row
          // stored a numeric id (e.g. '3'), the backend may reject it. Try to
          // resolve a proper UUID before calling create.
          String agroUuidToSend = h.agrochemicalId ?? '';

          if (!_looksLikeUuid(agroUuidToSend)) {
            // Try to fetch remote master list and map by id/name
            try {
              final master = await AgrochemicalApi.getAgrochemical();
              Map<String, dynamic>? found;
              for (final m in master) {
                final mid = (m['id'] ?? m['uuid'] ?? '').toString();
                final mname = (m['name'] ?? m['agrochemical_name'] ?? '').toString();
                if (mid.isNotEmpty && mid == (h.agrochemicalId ?? '')) {
                  found = m;
                  break;
                }
                if (mname.isNotEmpty && mname == (h.agrochemicalName ?? '')) {
                  found = m;
                  break;
                }
              }
              if (found != null) {
                agroUuidToSend = (found['uuid'] ?? found['id']).toString();
              }
            } catch (e) {
              print('⚠️ Could not fetch master agrochemical list while resolving id: $e');
            }

            // If still not a UUID, try local lookup
            if (!_looksLikeUuid(agroUuidToSend)) {
              try {
                final localMaster = await db.getAllAgrochemicals();
                for (final row in localMaster) {
                  final rid = (row['id'] ?? '').toString();
                  final rname = (row['agrochemical_name'] ?? '').toString();
                  if (rid.isNotEmpty && rid == (h.agrochemicalId ?? '')) {
                    agroUuidToSend = rid;
                    break;
                  }
                  if (rname.isNotEmpty && rname == (h.agrochemicalName ?? '')) {
                    agroUuidToSend = rid;
                    break;
                  }
                }
              } catch (e) {
                print('⚠️ Could not read local agrochemical lookup while resolving id: $e');
              }
            }
          }

          if (!_looksLikeUuid(agroUuidToSend)) {
            print('⚠️ Cannot resolve a valid agrochemical UUID for local row (agrochemicalId=${h.agrochemicalId}, name=${h.agrochemicalName}). Skipping sync for tree ${h.tree_uuid}');
            continue;
          }

          final resp = await AgrochemicalApi.createAgrochemicalRecord(
            tree_uuid: h.tree_uuid ?? '',
            agrochemical_uuid: agroUuidToSend,
            applied_at: h.applied_at ?? '',
            description: h.description ?? '',
          );

          // createAgrochemicalRecord returns a Map on success (or throws)
          if (resp['success'] == true || resp.containsKey('data')) {
            await db.markAsSynced(h.tree_uuid ?? '');
            print('✅ Synced new agrochemical record for tree ${h.tree_uuid}');
          } else {
            print('⚠️ Create agrochemical API returned unexpected response: $resp');
          }
        } catch (e) {
          print('❌ Failed to sync agrochemical record for tree ${h.tree_uuid}: $e');
        }
      }
    } catch (e) {
      print('⚠️ syncHealth failed: $e');
    }
  }
}