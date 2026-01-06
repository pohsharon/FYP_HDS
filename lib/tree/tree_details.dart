import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/tree_api.dart';
import 'package:fyp_hbs/tree/tab/health/health_tab.dart';
import 'package:fyp_hbs/tree/tab/harvest/harvest_tab.dart';
import 'package:fyp_hbs/tree/tab/agrochemical/agrochemical_tab.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fyp_hbs/tree/map_individual_tree.dart';
import 'package:fyp_hbs/tree/create_tree.dart';
import 'package:fyp_hbs/tree/tab/growthlog/growthlog_tab.dart';
import '../config.dart';
import 'package:fyp_hbs/models/tree_model.dart';
import 'package:fyp_hbs/models/tree_growth_model.dart';
import 'package:fyp_hbs/services/local%20database/tree_db.dart';
import 'package:fyp_hbs/services/local%20database/species_db.dart';
import 'package:fyp_hbs/services/local%20database/growth_db.dart';
import 'package:another_flushbar/flushbar.dart';
import '../utils/connectivity_helper.dart';


class TreeDetailsPage extends StatefulWidget {
  final String treeID;
  final bool refreshOnPop;

  const TreeDetailsPage({
    super.key,
    required this.treeID,
    this.refreshOnPop = false,
  });

  @override
  State<TreeDetailsPage> createState() => _TreeDetailsPageState();
}

class _TreeDetailsPageState extends State<TreeDetailsPage> {
  bool isLoading = true;
  Map<String, dynamic>? tree;
  bool _shouldRefresh = false;
  bool _isOnline = true;

  Map<String, dynamic> _normalizeTree(Map<String, dynamic> src) {
    final normalized = Map<String, dynamic>.from(src);

    // Normalize diameter/width so UI always has both keys.
    final widthVal = normalized['width'] ?? normalized['diameter'];
    if (widthVal != null) {
      normalized['width'] = widthVal;
      normalized['diameter'] = widthVal;
    }

    // Coerce numeric strings to double for height/width if possible so they render offline.
    double? _asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '');
    }

    final h = _asDouble(normalized['height']);
    if (h != null) normalized['height'] = h;

    final w = _asDouble(normalized['width']);
    if (w != null) normalized['width'] = w;

    return normalized;
  }

  @override
  void initState() {
    super.initState();
    _shouldRefresh = widget.refreshOnPop;
    _checkConnectivity();
    _loadTreeDetails();
  }

  Future<void> _checkConnectivity() async {
    try {
      final online = await ConnectivityHelper.hasInternetConnection();
      if (mounted) {
        setState(() => _isOnline = online);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isOnline = false);
      }
    }
  }

  void _markShouldRefresh() {
    if (!_shouldRefresh && mounted) {
      setState(() => _shouldRefresh = true);
    }
  }

  Future<bool> _handleWillPop() async {
    Navigator.pop(
      context,
      _shouldRefresh
          ? {
              'refreshList': true,
              'updatedId': tree?['uuid'] ?? widget.treeID,
            }
          : null,
    );
    return false;
  }

  Future<void> _loadTreeDetails() async {
    try {
      final data = await TreeApi.getTreeByUuid(widget.treeID);
      
      // 💾 Cache fetched tree to local DB immediately
      try {
        await TreeDB().upsertTreeFromApi(data);
      } catch (e) {
        print('⚠️ Failed to cache tree to local DB: $e');
      }
      
      if (!mounted) return;
      setState(() {
        tree = _normalizeTree(data);
        isLoading = false;
      });
      // Merge any cached growth measurements (offline cache) to show latest values
      try {
        final treeUuid = data['uuid'] ?? widget.treeID;
        await _mergeCachedGrowth(treeUuid);
      } catch (_) {}
    } catch (e1) {
      try {
        final data = await TreeApi.getTreeById(widget.treeID);
        
        // 💾 Cache fetched tree to local DB immediately
        try {
          await TreeDB().upsertTreeFromApi(data);
        } catch (e) {
          print('⚠️ Failed to cache tree to local DB: $e');
        }
        
        if (!mounted) return;
        setState(() {
          tree = _normalizeTree(data);
          isLoading = false;
        });
        // Merge cached growth measurements (if any) after loading by numeric id
        try {
          final treeUuid = data['uuid'] ?? widget.treeID;
          await _mergeCachedGrowth(treeUuid);
        } catch (_) {}
      } catch (e2) {
        // Try to load from local DB as a fallback (offline-created tree)
        try {
          final local = await TreeDB().fetchAllTrees();
          TreeModel? match;
          for (final m in local) {
            if (m.uuid == widget.treeID || m.id?.toString() == widget.treeID) {
              match = m;
              break;
            }
          }

          if (match != null) {
            // Convert TreeModel to the map shape expected by the UI
            final m = match;
            // try to resolve species name from local species table
            String speciesName = m.speciesId ?? 'Unknown';
            try {
              final speciesRows = await SpeciesDB().getAllSpecies();
              for (final s in speciesRows) {
                final sid = s['id']?.toString();
                if (sid != null && sid == (m.speciesId?.toString() ?? '')) {
                  speciesName = s['name']?.toString() ?? speciesName;
                  break;
                }
              }
            } catch (_) {
              // ignore and use fallback
            }

            final localMap = {
              'id': m.id ?? m.uuid,
              'uuid': m.uuid,
              'tree_tag': m.treeTag ?? 'Offline Tree',
              'species': {'id': m.speciesId, 'name': speciesName},
              'planted_at': m.plantedAt?.toIso8601String() ?? '',
              'latitude': m.latitude ?? 0.0,
              'longitude': m.longitude ?? 0.0,
              'thumbnail': m.thumbnail ?? '',
              'height': m.height ?? 0.0,
              'width': m.diameter ?? 0.0,
              'diameter': m.diameter ?? 0.0,
              'flowering_period': m.floweringPeriod ?? 0,
            };

            if (!mounted) return;
            setState(() {
              tree = _normalizeTree(localMap);
              isLoading = false;
            });
            // Merge cached growth measurements for this offline tree
            try {
              final treeUuid = localMap['uuid'] ?? widget.treeID;
              await _mergeCachedGrowth(treeUuid);
            } catch (_) {}
            return;
          }
        } catch (e3) {
          print('Failed to load tree from local DB: $e3');
        }

        if (mounted) {
          setState(() => isLoading = false);
          Flushbar(
            message: 'Error loading tree: $e2',
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(12),
            borderRadius: BorderRadius.circular(8),
          ).show(context);
        }
      }
    }
  }

  Future<void> _mergeCachedGrowth(dynamic treeUuid) async {
    final String uuid = (treeUuid?.toString() ?? widget.treeID);

    try {
      List<TreeGrowthModel> rows = await GrowthDB().fetchAllGrowths(
        treeUuid: uuid,
      );

      // If no rows found, optionally try relaxed match for local trees
      if (rows.isEmpty && uuid.startsWith('local_')) {
        final fallbackUuid = uuid.replaceFirst('local_', '');
        rows = await GrowthDB().fetchAllGrowths(treeUuid: fallbackUuid);
        print('⚠️ Relax fallback matched rows: ${rows.length}');
      }

      // Nothing to merge
      if (rows.isEmpty) {
        // Also print total rows in DB for debugging
        try {
          final all = await GrowthDB().fetchAllGrowths();
        } catch (_) {
        }
        return;
      }

      // Helper to read & parse date safely
      DateTime parseDate(TreeGrowthModel r) {
        try {
          return DateTime.tryParse(r.createdAt ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
        } catch (_) {
          return DateTime.fromMillisecondsSinceEpoch(0);
        }
      }

      // Select latest row
      rows.sort((a, b) => parseDate(b).compareTo(parseDate(a)));
      final latest = rows.first;

      final double? latestHeight = latest.height;
      final double? latestDiameter = latest.diameter; // <-- KEEP THIS NAME

      if (!mounted) return;

      // Determine the last-updated timestamp of the tree record (if available).
      DateTime treeUpdated = DateTime.fromMillisecondsSinceEpoch(0);
      try {
        final raw = tree?['updated_at'] ?? tree?['updatedAt'] ?? tree?['created_at'] ?? tree?['createdAt'];
        if (raw != null && raw.toString().isNotEmpty) {
          treeUpdated = DateTime.tryParse(raw.toString()) ?? treeUpdated;
        }
      } catch (_) {}

      final latestCreated = parseDate(latest);

      // Only apply growth values if the growth record is newer than the
      // tree's last-updated timestamp. This prevents older cached growth
      // rows from overwriting a freshly updated tree record in the UI.
      if (latestCreated.isAfter(treeUpdated)) {
        setState(() {
          tree ??= {};

          if (latestHeight != null && latestHeight > 0) {
            tree!['height'] = latestHeight;
          }

          if (latestDiameter != null && latestDiameter > 0) {
            // Keep both keys so UI that reads either 'width' or 'diameter' will show the value
            tree!['diameter'] = latestDiameter;
            tree!['width'] = latestDiameter;
          }
        });
      } else {
        // Growth record is older than the tree record; do not override.
      }
    } catch (e) {
      print('❌ Failed to merge cached growth: $e');
    }
  }

  Widget _buildTreeImage(String? thumbnail) {
    if (_isOnline && thumbnail != null && thumbnail.isNotEmpty) {
      // Build full URL to Supabase image
      final imageUrl = '${Config.supabaseBaseUrl}$thumbnail';

      return ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: Image.network(
          imageUrl,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultImage();
          },
        ),
      );
    } else {
      return _buildDefaultImage();
    }
  }

  Widget _buildDefaultImage() {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.grey[200],
      child: const Center(
        child: Text('No image available', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (tree == null) {
      return const Scaffold(body: Center(child: Text("Failed to load tree.")));
    }

    final String treeTag = tree!['tree_tag'] ?? 'Unknown';
    final String treeType = tree!['species']?['name'] ?? 'Unknown Type';
  final rawPlanted = tree!['planted_at'] ?? '';
  final String treeDate = rawPlanted.toString().trim().isEmpty
    ? 'Unknown Date'
    : (rawPlanted.toString().contains('T')
      ? rawPlanted.toString().split('T').first
      : rawPlanted.toString());
    final String treeImage = tree!['thumbnail'] ?? '';
    final String uuid = tree!['uuid'] ?? 'Unknown UUID';
    final String floweringPeriod = tree!['flowering_period']?.toString() ?? '-';
    final double height = double.tryParse(tree!['height'].toString()) ?? 0;
    final double width = double.tryParse(tree!['width'].toString()) ?? 0;
    final double latitude = double.tryParse(tree!['latitude'].toString()) ?? 0;
    final double longitude =
        double.tryParse(tree!['longitude'].toString()) ?? 0;

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Tree Details",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: AppColors.pakistanGreen,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () async {
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CreateTreePage(tree: tree)),
                );

                if (updated == true) {
                  // Tree was deleted; pop back to tree list with refresh signal
                  Navigator.pop(context, {'refreshList': true});
                  return;
                }

                if (updated is Map) {
                  if (updated['refreshList'] == true) {
                    _markShouldRefresh();
                  }

                  // Reload latest details so the page reflects the edits
                  await _loadTreeDetails();
                }
              },
            ),
          ],
        ),
          backgroundColor: AppColors.background,
          body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  if (_isOnline && treeImage.isNotEmpty) {
                    showDialog(
                      context: context,
                      builder:
                          (_) => Dialog(
                            backgroundColor: Colors.white,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                '${Config.supabaseBaseUrl}$treeImage',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Text('Image failed to load'),
                                  );
                                },
                              ),
                            ),
                          ),
                    );
                  }
                },
                child: _buildTreeImage(treeImage),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder:
                              (_) => Dialog(
                                backgroundColor: Colors.transparent,
                                insetPadding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 100,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      QrImageView(
                                        data: uuid,
                                        version: QrVersions.auto,
                                        size: 300,
                                        gapless: true,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        uuid,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        );
                      },
                      child: QrImageView(
                        data: uuid,
                        version: QrVersions.auto,
                        size: 80,
                        gapless: true,
                      ),
                    ),

                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            treeTag,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            treeType,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.pin_drop,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Lat: ${latitude.toStringAsFixed(5)}, Lon: ${longitude.toStringAsFixed(5)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                          final updated = await Navigator.push<bool?>(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => MapIndividualTreePage(
                                    treeLatitude: latitude,
                                    treeLongitude: longitude,
                                    treeTag: treeTag,
                                    treeUuid: uuid,
                                  ),
                            ),
                          );
                          if (updated == true) {
                            // Refresh details after possible location update
                            _loadTreeDetails();
                          }
                        },
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.pakistanGreen,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _InfoCard(label: "Planting Date", value: treeDate),
                    _InfoCard(
                      label: "Flowering Period",
                      value: floweringPeriod,
                    ),
                    _InfoCard(label: "Height", value: "$height m"),
                    _InfoCard(label: "Diameter", value: "$width m"),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const TabBar(
                labelColor: AppColors.hunterGreen,
                unselectedLabelColor: AppColors.hunterGreen,
                tabs: [
                  Tab(text: "Health"),
                  Tab(text: "Agrochemical"),
                  Tab(text: "Growth Log"),
                  Tab(text: "Harvest"),
                ],
                labelStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                unselectedLabelStyle: TextStyle(fontSize: 11),
                indicatorColor: AppColors.hunterGreen,
                indicatorWeight: 3,
              ),
              SizedBox(
                height:
                    MediaQuery.of(context).size.height *
                    0.35, // adjust as needed
                child: TabBarView(
                  children: [
                    HealthTabPage(treeTag: treeTag, treeUuid: uuid),
                    AgrochemicalTabPage(treeUuid: uuid, treeTag: treeTag),
                    GrowthLogTabPage(
                      treeUuid: uuid,
                      onGrowthLogSaved: () {
                        _markShouldRefresh();
                        _loadTreeDetails();
                      },
                    ),
                    HarvestTabPage(treeUuid: uuid),
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;

  const _InfoCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.42,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray400, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
