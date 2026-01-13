import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/tree_api.dart';
import 'package:intl/intl.dart';
import 'fruit_list.dart';
import 'package:fyp_hbs/services/local database/fruit_db.dart';
import 'package:fyp_hbs/services/local database/local_db.dart';
import 'package:fyp_hbs/utils/connectivity_helper.dart';
import 'package:fyp_hbs/fruit/create_fruit.dart';
import 'package:another_flushbar/flushbar.dart';

class HarvestTabPage extends StatefulWidget {
  final String treeUuid;
  const HarvestTabPage({super.key, required this.treeUuid});

  @override
  State<HarvestTabPage> createState() => _HarvestTabPageState();
}

class _HarvestTabPageState extends State<HarvestTabPage> {

  Future<List<Map<String, dynamic>>> fetchHarvests() async {
    final online = await ConnectivityHelper.hasInternetConnection();
    final treeLocalFruits = await FruitDB().fetchFruitsByTree(widget.treeUuid);
    final Set<String> localHarvestUuids = treeLocalFruits
        .map((f) => (f.harvest_uuid ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet();
    
    if (online) {
      try {
        final response = await TreeApi.getHarvestsByTreeId(widget.treeUuid);
        final List<Map<String, dynamic>> filtered = [];
        
        for (final ev in response) {
          try {
            final String? evUuid = (ev['uuid'] ?? ev['id'] ?? ev['harvest_uuid'])?.toString();
            final List<Map<String, dynamic>> eventFruits = [];
            bool includesTree = false;
            
            if (ev['fruits'] is List) {
              for (final f in ev['fruits']) {
                try {
                  final String fTree = (f['tree_uuid'] ?? '').toString();
                  final String fHarvest = (f['harvest_uuid'] ?? '').toString();
                  if (fTree == widget.treeUuid) {
                    includesTree = true;
                    eventFruits.add(Map<String, dynamic>.from(f));
                  } else if (localHarvestUuids.contains(fHarvest)) {
                    includesTree = true;
                    eventFruits.add(Map<String, dynamic>.from(f));
                  }
                } catch (_) {}
              }
            }

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
              filtered.add({
                'uuid': evUuid ?? '',
                'event_name': ev['event_name'] ?? ev['name'] ?? 'Harvest ${evUuid ?? ''}',
                'start_date': ev['start_date'] ?? ev['begin_date'] ?? ev['created_at'] ?? '',
                'end_date': ev['end_date'] ?? ev['finish_date'] ?? ev['harvested_at'] ?? '',
                'fruits': eventFruits,
              });
            }
          } catch (e) {
            print('⚠️ fetchHarvests: malformed event skipped: $e');
          }
        }

        return filtered;
      } catch (e) {
        print('⚠️ fetchHarvests: remote fetch failed, falling back to local cache: $e');
      }
    }

    try {
      final treeFruits = await FruitDB().fetchFruitsByTree(widget.treeUuid);
      if (treeFruits.isEmpty) return <Map<String, dynamic>>[];

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final f in treeFruits) {
        String rawHarvest = f.harvest_uuid ?? '';
        String key;
        if (rawHarvest.isNotEmpty && !rawHarvest.startsWith('gen_') && rawHarvest != 'unknown') {
          key = rawHarvest;
        } else {
          final dateRaw = (f.harvested_at ?? f.created_at ?? '').toString();
          String dateKey = '';
          if (dateRaw.isNotEmpty) {
            dateKey = dateRaw.contains('T') ? dateRaw.split('T').first : dateRaw;
          }
          if (dateKey.isEmpty) {
            key = rawHarvest.isNotEmpty ? rawHarvest : 'unknown';
          } else {
            key = 'gen_$dateKey';
          }
        }

        grouped.putIfAbsent(key, () => []).add(f.toMap());
      }

      final events = <Map<String, dynamic>>[];
      final allKeys = grouped.keys.toList();
      bool isReal(String k) => k != 'unknown' && !k.toString().startsWith('gen_');
      allKeys.sort((a, b) {
        final ra = isReal(a) ? 0 : 1;
        final rb = isReal(b) ? 0 : 1;
        if (ra != rb) return ra - rb;
        return a.compareTo(b);
      });

      final realKeys = allKeys.where((k) => isReal(k)).toList();
      if (realKeys.isNotEmpty) {
        final firstReal = realKeys.first;
        for (final k in List<String>.from(grouped.keys)) {
          if (!isReal(k) && k != firstReal) {
            final itemsToMove = grouped[k] ?? [];
            grouped[firstReal] = (grouped[firstReal] ?? []) + itemsToMove;
            grouped.remove(k);
          }
        }
      }

      final db = await LocalDB.getDatabase();
      for (final harvestUuid in grouped.keys.toList()) {
        final items = grouped[harvestUuid]!;
        String displayName = '';

        // Try to get event_name from harvest_events table first
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

        // If still empty and have fruits with event info, use that
        if (displayName.isEmpty && items.isNotEmpty) {
          final firstFruit = items.first;
          if (firstFruit['event_name'] != null && firstFruit['event_name'].toString().trim().isNotEmpty) {
            displayName = firstFruit['event_name'].toString();
          }
        }

        // Fallback to generic name if still empty
        if (displayName.isEmpty) {
          displayName = 'Cached harvest ${harvestUuid.substring(0, harvestUuid.length > 8 ? 8 : harvestUuid.length)}';
          print('⚠️ harvest_tab: using generic name for $harvestUuid');
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

  String _formatDateRange(String? startDate, String? endDate) {
    if (startDate == null || startDate.isEmpty) return '';
    
    try {
      final start = DateTime.parse(startDate);
      final fmt = DateFormat('MMM dd');
      
      if (endDate == null || endDate.isEmpty) {
        return '${fmt.format(start)}, ${start.year}';
      }
      
      final end = DateTime.parse(endDate);
      
      // Same month and year
      if (start.month == end.month && start.year == end.year) {
        return '${DateFormat('MMM').format(start)} ${start.day}-${end.day}, ${start.year}';
      }
      
      // Different months, same year
      if (start.year == end.year) {
        return '${fmt.format(start)} - ${fmt.format(end)}, ${start.year}';
      }
      
      // Different years
      return '${fmt.format(start)}, ${start.year} - ${fmt.format(end)}, ${end.year}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchHarvests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: AppColors.hunterGreen,
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading harvests',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gray800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.gray600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        final harvests = snapshot.data ?? [];
        
        // Show empty state if no harvests
        if (harvests.isEmpty) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Add Fruit button
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.hunterGreen.withOpacity(0.1),
                          AppColors.mossGreen.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.hunterGreen.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final hasInternet = await ConnectivityHelper.hasInternetConnection();
                          if (!hasInternet) {
                            if (mounted) {
                              await Flushbar(
                                message: 'Editing is disabled while offline',
                                icon: const Icon(Icons.cloud_off, color: Colors.white),
                                backgroundColor: Colors.orange.shade700,
                                duration: const Duration(seconds: 2),
                                borderRadius: BorderRadius.circular(12),
                                margin: const EdgeInsets.all(12),
                                flushbarPosition: FlushbarPosition.TOP,
                              ).show(context);
                            }
                            return;
                          }
                          
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateFruitPage(prefilledTreeUuid: widget.treeUuid),
                            ),
                          );
                          if (result == true) {
                            setState(() {});
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Icon container
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.hunterGreen,
                                      AppColors.mossGreen,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.hunterGreen.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add_circle_outline,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              
                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Add New Fruit',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppColors.hunterGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Record a new fruit harvest',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.gray600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Arrow
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.hunterGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.arrow_forward,
                                  size: 20,
                                  color: AppColors.hunterGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Empty state message
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.gray200,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 40,
                          color: AppColors.gray600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No harvest events yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the Add New Fruit button above to create your first harvest record',
                        style: TextStyle(fontSize: 14, color: AppColors.gray600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: harvests.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            // Add Fruit button at the top
            // Replace the Add Fruit button section in your itemBuilder with this:

// Add Fruit button at the top
if (index == 0) {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.hunterGreen.withOpacity(0.1),
          AppColors.mossGreen.withOpacity(0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: AppColors.hunterGreen.withOpacity(0.3),
        width: 1.5,
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final hasInternet = await ConnectivityHelper.hasInternetConnection();
          if (!hasInternet) {
            if (mounted) {
              await Flushbar(
                message: 'Editing is disabled while offline',
                icon: const Icon(Icons.cloud_off, color: Colors.white),
                backgroundColor: Colors.orange.shade700,
                duration: const Duration(seconds: 2),
                borderRadius: BorderRadius.circular(12),
                margin: const EdgeInsets.all(12),
                flushbarPosition: FlushbarPosition.TOP,
              ).show(context);
            }
            return;
          }
          
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateFruitPage(prefilledTreeUuid: widget.treeUuid),
            ),
          );
          if (result == true) {
            setState(() {});
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.hunterGreen,
                      AppColors.mossGreen,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.hunterGreen.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add New Fruit',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.hunterGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Record a new fruit harvest',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.gray600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.hunterGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward,
                  size: 20,
                  color: AppColors.hunterGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
            
            final harvest = harvests[index - 1];
            final eventName = harvest['event_name'] ?? 'Unknown Event';
            final startDate = harvest['start_date'];
            final endDate = harvest['end_date'];
            final dateRange = _formatDateRange(startDate, endDate);
            final fruitCount = (harvest['fruits'] as List?)?.length ?? 0;
            
            return Card(
              color: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.gray300, width: 1.5),
              ),
              elevation: 0,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FruitListPage(
                        treeUuid: widget.treeUuid,
                        harvestUuid: harvest['uuid'] ?? harvest['harvest_uuid'] ?? '',
                        eventName: harvest['event_name'],
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [                                          
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eventName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.hunterGreen,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (dateRange.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: AppColors.gray500,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      dateRange,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.gray600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 14,
                                  color: AppColors.gray500,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$fruitCount ${fruitCount == 1 ? 'fruit' : 'fruits'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.gray600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Arrow
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.hunterGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AppColors.hunterGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}