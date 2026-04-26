import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/tree_api.dart';
import 'package:fyp_hbs/tree/tab/health/health_tab.dart';
import 'package:fyp_hbs/tree/tab/harvest/harvest_tab.dart';
import 'package:fyp_hbs/tree/tab/agrochemical/agrochemical_tab.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:fyp_hbs/tree/map_individual_tree.dart';
import 'package:fyp_hbs/tree/create_tree.dart';
import 'package:fyp_hbs/tree/tab/growthlog/growthlog_tab.dart';
import 'package:fyp_hbs/utils/connectivity_helper.dart';
import 'package:fyp_hbs/services/local%20database/species_db.dart';
import 'package:fyp_hbs/services/local%20database/tree_db.dart';
import 'package:fyp_hbs/models/tree_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fyp_hbs/models/tree_growth_model.dart';
import 'package:fyp_hbs/services/local%20database/growth_db.dart';
import '../config.dart';
import 'package:another_flushbar/flushbar.dart';

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
  String _floweringPeriod = '-';
  // Labels attached to this tree (temporary in-memory list)
  List<Map<String, dynamic>> labels = [];

  Map<String, dynamic> _normalizeTree(Map<String, dynamic> src) {
    final normalized = Map<String, dynamic>.from(src);

    // Normalize diameter/width so UI always has both keys.
    final widthVal = normalized['width'] ?? normalized['diameter'];
    if (widthVal != null) {
      normalized['width'] = widthVal;
      normalized['diameter'] = widthVal;
    }

    // Coerce numeric strings to double for height/width if possible so they render offline.
    double? asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '');
    }

    final h = asDouble(normalized['height']);
    if (h != null) normalized['height'] = h;

    final w = asDouble(normalized['width']);
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

  void _showAddLabelSheet(BuildContext context) {
    // kept for compatibility; prefer calling with uuid in build
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddLabelSheet(
        onLabelAdded: (labelMap) => setState(() => labels.add(labelMap)),
      ),
    );
  }

  void _showAddLabelSheetForTree(BuildContext context, String treeUuid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddLabelSheet(
        treeUuid: treeUuid,
        existingLabels: labels,
        onLabelAdded: (labelMap) async {
          // attach via API then refresh labels
          try {
            // Resolve numeric tree id; server expects numeric bigint id, not UUID.
            String? numericId;
            try {
              final localId = tree?['id'] ?? tree?['tree_id'];
              if (localId != null) {
                final s = localId.toString();
                if (int.tryParse(s) != null) numericId = s;
              }
            } catch (_) {}

            if (numericId == null) {
              try {
                final srv = await TreeApi.getTreeByUuid(treeUuid);
                Map<String, dynamic>? tmap;
                if (srv is Map && srv.containsKey('data')) {
                  final d = srv['data'];
                  if (d is Map) tmap = Map<String, dynamic>.from(d);
                } else if (srv is Map) {
                  tmap = Map<String, dynamic>.from(srv);
                }
                if (tmap != null && tmap.containsKey('id')) {
                  final sid = tmap['id']?.toString();
                  if (sid != null && int.tryParse(sid) != null) numericId = sid;
                }
              } catch (_) {}
            }

            Map<String, dynamic> attached = {};
            if (numericId != null) {
              attached = await TreeApi.attachLabel(
                treeId: numericId,
                label: labelMap['label'] ?? labelMap['name'] ?? '',
                color: labelMap['color']?.toString(),
              );
            } else {
              // No numeric id available (likely offline-created tree). Persist locally and skip server attach.
              attached = Map<String, dynamic>.from(labelMap);
            }
            // If server returned label object, use it; else use provided map
            Map<String, dynamic> useMap = {};
            if (attached.containsKey('data')) {
              final d = attached['data'];
              if (d is Map && d.containsKey('label')) {
                useMap = Map<String, dynamic>.from(d['label']);
              }
            }
            if (useMap.isEmpty) useMap = Map<String, dynamic>.from(labelMap);
            setState(() => labels.add(useMap));
          } catch (e) {
            print('⚠️ Failed to attach label: $e');
            // fallback: still add locally
            setState(() => labels.add(Map<String, dynamic>.from(labelMap)));
          }
        },
      ),
    );
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
          ? {'refreshList': true, 'updatedId': tree?['uuid'] ?? widget.treeID}
          : null,
    );
    return false;
  }

  Future<void> _loadTreeDetails() async {
    try {
      var data = await TreeApi.getTreeByUuid(widget.treeID);

      // Unwrap common API response shapes: {data: {...}} or {data: {data: {...}}}
      try {
        if (data is Map && data.containsKey('data')) {
          final inner = data['data'];
          if (inner is Map && inner.containsKey('data')) {
            final inner2 = inner['data'];
            if (inner2 is Map) data = Map<String, dynamic>.from(inner2);
          } else if (inner is Map) {
            data = Map<String, dynamic>.from(inner);
          }
        }
      } catch (_) {}

      // 💾 Cache fetched tree to local DB immediately
      try {
        await TreeDB().upsertTreeFromApi(data);
      } catch (e) {
        print('⚠️ Failed to cache tree to local DB: $e');
      }

      if (!mounted) return;
      setState(() {
        tree = _normalizeTree(Map<String, dynamic>.from(data));
        isLoading = false;
      });

        // Load labels for this tree
        try {
          final uuidStr = (data['uuid'] ?? widget.treeID).toString();
          await _loadTreeLabels(uuidStr);
        } catch (_) {}

      // Fetch flowering period from dedicated endpoint
      _fetchFloweringPeriod((data['uuid'] ?? widget.treeID).toString());

      // Merge any cached growth measurements (offline cache) to show latest values
      try {
        final treeUuid = data['uuid'] ?? widget.treeID;
        await _mergeCachedGrowth(treeUuid);
      } catch (_) {}
    } catch (e1) {
      try {
        var data = await TreeApi.getTreeById(widget.treeID);

        // Unwrap common API response shapes
        try {
          if (data is Map && data.containsKey('data')) {
            final inner = data['data'];
            if (inner is Map && inner.containsKey('data')) {
              final inner2 = inner['data'];
              if (inner2 is Map) data = Map<String, dynamic>.from(inner2);
            } else if (inner is Map) {
              data = Map<String, dynamic>.from(inner);
            }
          }
        } catch (_) {}

        // 💾 Cache fetched tree to local DB immediately
        try {
          await TreeDB().upsertTreeFromApi(data);
        } catch (e) {
          print('⚠️ Failed to cache tree to local DB: $e');
        }

        if (!mounted) return;
        setState(() {
          tree = _normalizeTree(Map<String, dynamic>.from(data));
          isLoading = false;
        });

        // Load labels for this tree
        try {
          final uuidStr = (data['uuid'] ?? widget.treeID).toString();
          await _loadTreeLabels(uuidStr);
        } catch (_) {}

        // Fetch flowering period from dedicated endpoint
        _fetchFloweringPeriod((data['uuid'] ?? widget.treeID).toString());

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
              'flowering_status': m.floweringStatus ?? '-',
              'area': m.area ?? '-',
              'terrace': m.terrace ?? '-',
              'water_valve': m.waterValve ?? '-',
            };

            if (!mounted) return;
            setState(() {
              tree = _normalizeTree(localMap);
              isLoading = false;
            });

            // Load labels (from local DB may not be available; try server)
            try {
              final uuidStr = (localMap['uuid'] as String?) ?? widget.treeID;
              await _loadTreeLabels(uuidStr);
            } catch (_) {}

            // Fetch flowering period from dedicated endpoint
            _fetchFloweringPeriod(
              (localMap['uuid'] as String?) ?? widget.treeID,
            );

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

  Future<void> _fetchFloweringPeriod(String uuid) async {
    try {
      final result = await TreeApi.getTreeFloweringPeriod(uuid);

      if (mounted) {
        String period = '-';

        // Extract flowering_period from the response
        // Check if response has 'data' wrapper
        if (result.containsKey('data') && result['data'] is Map) {
          period = result['data']['flowering_period']?.toString() ?? '-';
        } else {
          // Direct response format
          period = result['flowering_period']?.toString() ?? '-';
        }

        // Cache the flowering period to SharedPreferences
        if (period != '-') {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('flowering_period_$uuid', period);
          } catch (e) {
            print('⚠️ Failed to cache flowering period: $e');
          }
        }

        setState(() => _floweringPeriod = period);
      }
    } catch (e) {
      print('⚠️ Failed to fetch flowering period: $e');

      // Try to load from cache when API fails (offline mode)
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedPeriod = prefs.getString('flowering_period_$uuid');

        if (cachedPeriod != null && mounted) {
          setState(() => _floweringPeriod = cachedPeriod);
          print('📦 Loaded flowering period from cache: $cachedPeriod');
          return;
        }
      } catch (cacheErr) {
        print('⚠️ Failed to load flowering period from cache: $cacheErr');
      }

      // Fall back to tree's stored flowering_period if available
      if (mounted && tree != null) {
        final fallback = tree!['flowering_period']?.toString() ?? '-';
        if (fallback != '-') {
          setState(() => _floweringPeriod = fallback);
          print('📦 Using fallback flowering period from tree data: $fallback');
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
        } catch (_) {}
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
        final raw =
            tree?['updated_at'] ??
            tree?['updatedAt'] ??
            tree?['created_at'] ??
            tree?['createdAt'];
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

  Future<void> _loadTreeLabels(String treeUuid) async {
    try {
      // Attempt to resolve a numeric tree id. Some local rows only have UUIDs
      // (offline-created). The labels endpoint expects a numeric id (bigint).
      String? numericId;

      try {
        final localId = tree?['id'] ?? tree?['tree_id'];
        if (localId != null) {
          final s = localId.toString();
          if (int.tryParse(s) != null) numericId = s;
        }
      } catch (_) {}

      // If we don't have a numeric id locally, try fetching the server record
      // by UUID to obtain its numeric id. If that fails, skip the server call.
      if (numericId == null) {
        try {
          final srv = await TreeApi.getTreeByUuid(treeUuid);
          Map<String, dynamic>? tmap;
          if (srv is Map && srv.containsKey('data')) {
            final d = srv['data'];
            if (d is Map) tmap = Map<String, dynamic>.from(d);
          } else if (srv is Map) {
            tmap = Map<String, dynamic>.from(srv);
          }

          if (tmap != null && tmap.containsKey('id')) {
            final sid = tmap['id']?.toString();
            if (sid != null && int.tryParse(sid) != null) numericId = sid;
          }
        } catch (_) {
          // ignore - we will simply not call the labels endpoint when numeric id unavailable
        }
      }

      if (numericId == null) {
        // No numeric id available: avoid calling the server with a UUID
        return;
      }

      final resp = await TreeApi.getTreeLabels(treeId: numericId);
      List<Map<String, dynamic>> found = [];

      if (resp.containsKey('data')) {
        final d = resp['data'];
        if (d is Map && d.containsKey('labels')) {
          final labs = d['labels'];
          if (labs is List) {
            found = labs.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
          }
        } else if (d is List) {
          found = d.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
        }
      } else if (resp.containsKey('labels') && resp['labels'] is List) {
        found = (resp['labels'] as List).map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
      }

      if (mounted) {
        setState(() {
          labels = found;
        });
      }
    } catch (e) {
      print('⚠️ Failed to load tree labels: $e');
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
    final String treeId = tree!['id']?.toString() ?? '';
    final String treeType = tree!['species']?['name'] ?? 'Unknown Type';
    final rawPlanted = tree!['planted_at'] ?? '';
    final String treeDate =
        rawPlanted.toString().trim().isEmpty
            ? '-'
            : (rawPlanted.toString().contains('T')
                ? rawPlanted.toString().split('T').first
                : rawPlanted.toString());
    final String treeImage = tree!['thumbnail'] ?? '';
    final String uuid = tree!['uuid'] ?? 'Unknown UUID';
    final String floweringPeriod = _floweringPeriod;
    final double height = double.tryParse(tree!['height'].toString()) ?? 0;
    final double width = double.tryParse(tree!['width'].toString()) ?? 0;
    final double latitude = double.tryParse(tree!['latitude'].toString()) ?? 0;
    final double longitude =
        double.tryParse(tree!['longitude'].toString()) ?? 0;
    final String area = tree!['area']?.toString() ?? '-';
    final String terrace = tree!['terrace']?.toString() ?? '-';
    final String waterValve = tree!['water_valve']?.toString() ?? '-';
    final String flowering_status = tree!['flowering_status']?.toString() ?? '-';

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text(
              "Tree Details",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: AppColors.pakistanGreen,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () async {
                  if (!_isOnline) {
                    await Flushbar(
                      message: 'Editing is disabled while offline',
                      icon: const Icon(Icons.cloud_off, color: Colors.white),
                      backgroundColor: Colors.orange.shade700,
                      duration: const Duration(seconds: 2),
                      borderRadius: BorderRadius.circular(12),
                      margin: const EdgeInsets.all(12),
                      flushbarPosition: FlushbarPosition.TOP,
                    ).show(context);
                    return;
                  }

                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateTreePage(tree: tree),
                    ),
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
          body: NestedScrollView(
            headerSliverBuilder:
                (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image display removed per request.
                        // Original GestureDetector + image code commented out below for reference.
                        /*
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
                    */
                        const SizedBox.shrink(),
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
                                          insetPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 30,
                                                vertical: 100,
                                              ),
                                          child: Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.15),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                QrImageView(
                                                  data: '${Config.productBaseUrl}/product-details/$uuid',
                                                  version: QrVersions.auto,
                                                  size: 300,
                                                  gapless: true,
                                                ),
                                                const SizedBox(height: 12),
                                                ElevatedButton.icon(
                                                  onPressed: () async {
                                                    final productUrl = '${Config.productBaseUrl}/product-details/$uuid';
                                                    try {
                                                      await Clipboard.setData(ClipboardData(text: productUrl));
                                                    } catch (_) {}
                                                    Navigator.of(context).pop();
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Link copied to clipboard'),
                                                        duration: Duration(seconds: 2),
                                                      ),
                                                    );
                                                  },
                                                  icon: const Icon(Icons.copy),
                                                  label: const Text('Copy link'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: AppColors.pakistanGreen,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                  );
                                },
                                child: QrImageView(
                                  data: '${Config.productBaseUrl}/product-details/$uuid',
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
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
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
                              _InfoCard(label: "Area", value: area),
                              _InfoCard(label: "Terrace", value: terrace),
                              _InfoCard(
                                label: "Water Valve",
                                value: waterValve,
                              ),
                              // _InfoCard(
                              //   label: "Planting Date",
                              //   value: treeDate,
                              // ),
                              _InfoCard(
                                label: "Flowering Period",
                                value: floweringPeriod,
                              ),
                             
                              _InfoCard(label: "Height", value: "$height ft"),
                              _InfoCard(label: "Diameter", value: "$width inch"),
                            ],
                          ),
                        ),
                        // After your Padding(cards Wrap), add:
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: AppColors.pakistanGreen,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        "Labels",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                        onPressed:
                                            () => _showAddLabelSheetForTree(context, uuid),
                                    icon: const Icon(
                                      Icons.add,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      "Add Label",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      backgroundColor: AppColors.sage,
                                      shape: StadiumBorder(),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              labels.isEmpty
                                  ? const Text(
                                      "No labels yet",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: labels.map((labelMap) {
                                        return _LabelChip(
                                          labelMap: labelMap,
                                          onDelete: () async {
                                            final confirmed = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Remove label'),
                                                content: const Text('Are you sure you want to remove this label from the tree?'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
                                                ],
                                              ),
                                            );

                                            if (confirmed != true) return;

                                            // Attempt server-side delete if numeric tree id and label id available
                                            try {
                                              String? numericId;
                                              try {
                                                final localId = tree?['id'] ?? tree?['tree_id'];
                                                if (localId != null) {
                                                  final s = localId.toString();
                                                  if (int.tryParse(s) != null) numericId = s;
                                                }
                                              } catch (_) {}

                                              if (numericId == null) {
                                                try {
                                                  final uuid = (tree?['uuid'] ?? widget.treeID).toString();
                                                  final srv = await TreeApi.getTreeByUuid(uuid);
                                                  Map<String, dynamic>? tmap;
                                                  if (srv is Map && srv.containsKey('data')) {
                                                    final d = srv['data'];
                                                    if (d is Map) tmap = Map<String, dynamic>.from(d);
                                                  } else if (srv is Map) {
                                                    tmap = Map<String, dynamic>.from(srv);
                                                  }
                                                  if (tmap != null && tmap.containsKey('id')) {
                                                    final sid = tmap['id']?.toString();
                                                    if (sid != null && int.tryParse(sid) != null) numericId = sid;
                                                  }
                                                } catch (_) {}
                                              }

                                              final labelId = labelMap['id']?.toString();
                                              if (numericId != null && labelId != null && labelId.isNotEmpty) {
                                                await TreeApi.deleteTreeLabel(treeId: numericId, labelId: labelId);
                                                if (mounted) setState(() => labels.remove(labelMap));
                                              } else {
                                                // Fallback: remove locally when server-side delete not possible
                                                if (mounted) setState(() => labels.remove(labelMap));
                                              }
                                            } catch (e) {
                                              print('⚠️ Failed to delete label: $e');
                                              try {
                                                Flushbar(
                                                  message: 'Failed to remove label: ${e.toString()}',
                                                  backgroundColor: Colors.red.shade700,
                                                  duration: const Duration(seconds: 3),
                                                ).show(context);
                                              } catch (_) {}
                                            }
                                          },
                                        );
                                      }).toList(),
                                    ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: AppColors.background,
                    toolbarHeight: 0,
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(50),
                      child: TabBar(
                        labelColor: AppColors.hunterGreen,
                        unselectedLabelColor: AppColors.hunterGreen,
                        tabs: const [
                          Tab(text: "Health"),
                          Tab(text: "Agrochemical"),
                          Tab(text: "Growth Log"),
                          Tab(text: "Harvest"),
                        ],
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        unselectedLabelStyle: const TextStyle(fontSize: 11),
                        indicatorColor: AppColors.hunterGreen,
                        indicatorWeight: 3,
                      ),
                    ),
                  ),
                ],
            body: TabBarView(
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
                
                HarvestTabPage(treeUuid: uuid, id: treeId),
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

/// Bottom sheet to add a label
class AddLabelSheet extends StatefulWidget {
  /// treeUuid can be provided so that parent can attach via API.
  final String? treeUuid;
  final List<Map<String, dynamic>>? existingLabels;
  final void Function(Map<String, dynamic>) onLabelAdded;
  const AddLabelSheet({required this.onLabelAdded, this.treeUuid, this.existingLabels});

  @override
  State<AddLabelSheet> createState() => _AddLabelSheetState();
}

class _AddLabelSheetState extends State<AddLabelSheet> {
  final TextEditingController _ctrl = TextEditingController();
  List<Map<String, dynamic>> _allLabels = [];
  List<Map<String, dynamic>> _available = [];
  String? _selectedColor;

  final List<String> _presetColors = [
    '#FF5733', // orange
    '#2ECC71', // green
    '#3498DB', // blue
    '#9B59B6', // purple
    '#F1C40F', // yellow
    '#FFFFFF', // white
  ];

  @override
  void initState() {
    super.initState();
    _fetchAllLabels();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAllLabels() async {
    try {
      final resp = await TreeApi.getLabels();
      List<Map<String, dynamic>> found = [];
      if (resp.containsKey('data') && resp['data'] is List) {
        found = (resp['data'] as List).map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
      }

      setState(() {
        _allLabels = found;
        _available = _allLabels.where((l) {
          final lid = l['id']?.toString();
          return !(widget.existingLabels ?? []).any((el) => (el['id']?.toString() ?? '') == (lid ?? ''));
        }).toList();
      });
    } catch (e) {
      print('⚠️ Failed to fetch labels list: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Label',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (_available.isNotEmpty) ...[
            const Text('Select from existing labels', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _available.map((l) {
                final colorHex = l['color']?.toString();
                final bg = _parseColor(colorHex);
                final txt = (l['label'] ?? l['name'] ?? '').toString();
                final txtColor = (bg.computeLuminance() < 0.5) ? Colors.white : Colors.black87;
                return ActionChip(
                  label: Text(txt, style: TextStyle(color: txtColor)),
                  backgroundColor: bg,
                  onPressed: () {
                    widget.onLabelAdded(Map<String, dynamic>.from(l));
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          const Text('Or create a new label', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(hintText: 'Enter label name'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          const Text('Pick a color (optional)', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _presetColors.map((hex) {
              final c = _parseColor(hex);
              final selected = _selectedColor == hex;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = hex),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c,
                    border: Border.all(color: selected ? AppColors.hunterGreen : Colors.grey.shade300, width: selected ? 2 : 1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _submit, child: const Text('Add')),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Color _parseColor(String? hex, {Color fallback = Colors.grey}) {
    if (hex == null) return fallback;
    try {
      var h = hex.trim();
      if (h.startsWith('#')) h = h.substring(1);
      if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
      final v = int.parse(h, radix: 16);
      return Color(0xFF000000 | v);
    } catch (_) {
      return fallback;
    }
  }

  void _submit() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    final labelMap = {
      'label': v,
      'name': v,
      if (_selectedColor != null) 'color': _selectedColor,
    };
    widget.onLabelAdded(Map<String, dynamic>.from(labelMap));
    Navigator.pop(context);
  }
}

class _LabelChip extends StatelessWidget {
  final Map<String, dynamic> labelMap;
  final VoidCallback? onDelete;
  const _LabelChip({required this.labelMap, this.onDelete});

  Color _parseColor(String? hex, {Color fallback = Colors.grey}) {
    if (hex == null) return fallback;
    try {
      var h = hex.trim();
      if (h.startsWith('#')) h = h.substring(1);
      if (h.length == 3) {
        h = h.split('').map((c) => '$c$c').join();
      }
      final v = int.parse(h, radix: 16);
      return Color(0xFF000000 | v);
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (labelMap['label'] ?? labelMap['name'] ?? '').toString();
    final colorHex = labelMap['color']?.toString();
    final bg = _parseColor(colorHex, fallback: Colors.white);
    // choose text color based on luminance
    final textColor = (bg.computeLuminance() < 0.5) ? Colors.white : Colors.black87;

    return Chip(
      label: Text(name, style: TextStyle(color: textColor)),
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: onDelete,
      backgroundColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.gray400),
      ),
    );
  }
}
