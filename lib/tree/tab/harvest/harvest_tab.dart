import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/tree_api.dart';
import 'fruit_list.dart';
import 'package:fyp_hbs/services/local database/fruit_db.dart';
import 'package:fyp_hbs/services/local database/local_db.dart';
import 'package:fyp_hbs/utils/connectivity_helper.dart';

class HarvestTabPage extends StatelessWidget {
  final String treeUuid;
  const HarvestTabPage({super.key, required this.treeUuid});

  Future<List<Map<String, dynamic>>> fetchHarvests() async {
    // Prefer remote when online, but fall back to local cached fruits grouped by harvest_uuid
    final online = await ConnectivityHelper.hasInternetConnection();
    // load local fruits for this tree so we can filter remote events by local participation
    final treeLocalFruits = await FruitDB().fetchFruitsByTree(treeUuid);
    // build a set of known harvest UUIDs that this tree participated in (from local cache)
    final Set<String> localHarvestUuids = treeLocalFruits
        .map((f) => (f.harvest_uuid ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet();
    if (online) {
      try {
        final response = await TreeApi.getHarvestsByTreeId(treeUuid);
        // filter remote events to only those the tree participated in
        final List<Map<String, dynamic>> filtered = [];
        for (final ev in response) {
          try {
            // normalize event id
            final String? evUuid = (ev['uuid'] ?? ev['id'] ?? ev['harvest_uuid'])?.toString();
            // collect fruits that belong to this tree from remote event (if present)
            final List<Map<String, dynamic>> eventFruits = [];
            bool includesTree = false;
            if (ev['fruits'] is List) {
              for (final f in ev['fruits']) {
                try {
                  final String fTree = (f['tree_uuid'] ?? '').toString();
                  final String fHarvest = (f['harvest_uuid'] ?? '').toString();
                  if (fTree == treeUuid) {
                    includesTree = true;
                    eventFruits.add(Map<String, dynamic>.from(f));
                  } else if (localHarvestUuids.contains(fHarvest)) {
                    // if local cache indicates this harvest belongs to our tree, include it
                    includesTree = true;
                    eventFruits.add(Map<String, dynamic>.from(f));
                  }
                } catch (_) {}
              }
            }

            // if remote event didn't include tree fruits, check local cache by harvest_uuid
            if (!includesTree && evUuid != null && evUuid.isNotEmpty) {
              if (localHarvestUuids.contains(evUuid)) {
                final localMatches = treeLocalFruits.where((f) => (f.harvest_uuid ?? '') == evUuid).toList();
                if (localMatches.isNotEmpty) {
                  includesTree = true;
                  for (final lm in localMatches) {
                    eventFruits.add(lm.toMap());
                  }
                }
              }
            }

            if (includesTree) {
              // build a normalized event shape expected by UI
              filtered.add({
                'uuid': evUuid ?? '',
                'event_name': ev['event_name'] ?? ev['name'] ?? 'Harvest ${evUuid ?? ''}',
                'start_date': ev['start_date'] ?? ev['begin_date'] ?? ev['created_at'] ?? '',
                'end_date': ev['end_date'] ?? ev['finish_date'] ?? ev['harvested_at'] ?? '',
                'fruits': eventFruits,
              });
            }
          } catch (e) {
            // ignore malformed event entries
            print('⚠️ fetchHarvests: malformed event skipped: $e');
          }
        }

        return filtered;
      } catch (e) {
        print('⚠️ fetchHarvests: remote fetch failed, falling back to local cache: $e');
      }
    }

    // Offline or remote failed: build harvest events from local fruits table
    try {
      final treeFruits = await FruitDB().fetchFruitsByTree(treeUuid);
      print("Fruits offline:"+ treeFruits.toString());
      if (treeFruits.isEmpty) return <Map<String, dynamic>>[];

      // group by harvest_uuid
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final f in treeFruits) {
        final h = f.harvest_uuid ?? 'unknown';
        grouped.putIfAbsent(h, () => []).add(f.toMap());
      }

      // convert groups into harvest event shapes expected by UI
      // Prefer returning real UUID groups (not generated ones like 'gen_...')
      final events = <Map<String, dynamic>>[];

      // choose which harvest uuids to show: prefer non-generated UUIDs
      final realKeys = grouped.keys.where((k) => k != 'unknown' && !k.toString().startsWith('gen_')).toList();
      final keysToInclude = realKeys.isNotEmpty ? realKeys : grouped.keys.toList();

      // Debug: print selected harvest uuids
      print('Selected harvest UUIDs for display: ${keysToInclude.join(', ')}');

      final db = await LocalDB.getDatabase();
      for (final harvestUuid in keysToInclude) {
        final items = grouped[harvestUuid]!;
        String displayName = 'Cached harvest ${harvestUuid.substring(0, harvestUuid.length > 8 ? 8 : harvestUuid.length)}';

        if (harvestUuid != 'unknown' && !harvestUuid.toString().startsWith('gen_')) {
          try {
            final rows = await db.query(
              'harvest_events',
              columns: ['event_name', 'start_date', 'end_date'],
              where: 'uuid = ?',
              whereArgs: [harvestUuid],
              limit: 1,
            );
            if (rows.isNotEmpty) {
              final r = rows.first;
              if (r['event_name'] != null && r['event_name'].toString().trim().isNotEmpty) {
                displayName = r['event_name'].toString();
              }
            }
          } catch (e) {
            print('⚠️ harvest_tab: failed to read harvest_events for $harvestUuid: $e');
          }
        }

        events.add({
          'uuid': harvestUuid,
          'event_name': displayName,
          'start_date': items.first['harvested_at'] ?? '',
          'end_date': items.first['harvested_at'] ?? '',
          'fruits': items,
        });
      }

      return events;
    } catch (e) {
      print('⚠️ fetchHarvests fallback failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchHarvests(), // Replace with your API call
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final harvests = snapshot.data ?? [];
        if (harvests.isEmpty) {
          return const Center(child: Text('No harvest events found.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          itemCount: harvests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final harvest = harvests[index];
            return Card(
              // color: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.gray300),
              ),
              
              elevation: 0,
              child: ListTile(
                title: Text(
                  harvest['event_name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.hunterGreen),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FruitListPage(
                        treeUuid: treeUuid,
                        harvestUuid: harvest['uuid'] ?? harvest['harvest_uuid'] ?? '',
                      ),
                    ),
                  );
                                },
              ),
            );
          },
        );
      },
    );
  }
}