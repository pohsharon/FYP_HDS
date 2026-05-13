import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/tree_api.dart';
import 'package:fyp_hbs/services/api/harvest_api.dart';
import 'package:intl/intl.dart';
import 'package:another_flushbar/flushbar.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
class _HarvestTheme {
  // Botanical palette
  // colors now referenced directly from AppColors in the file

  // Flowering status chip colours
  static Color statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'A':
        return const Color(0xFF52B788); // fresh green
      case 'B':
        return const Color(0xFF74C69D);
      case 'C':
        return const Color(0xFFB7E4C7);
      case 'D':
        return const Color(0xFFE9C46A); // amber
      case 'X':
        return const Color(0xFFE07A5F); // faded red
      default:
        return const Color(0xFFCED4DA);
    }
  }

  static Color statusText(String s) {
    switch (s.toUpperCase()) {
      case 'A':
      case 'B':
        return Colors.white;
      case 'C':
        return const Color(0xFF1B5E20);
      case 'D':
        return const Color(0xFF7B5E00);
      case 'X':
        return Colors.white;
      default:
        return const Color(0xFF495057);
    }
  }

  static String statusDescription(String s) {
    switch (s.toUpperCase()) {
      case 'A':
        return '> 30';
      case 'B':
        return '20 - 30';
      case 'C':
        return '10 - 20';
      case 'D':
        return '<10';
      case 'X':
        return 'No flowering';
      default:
        return 'Unknown';
    }
  }
}

// ─── Widget ───────────────────────────────────────────────────────────────────
class HarvestTabPage extends StatefulWidget {
  final String treeUuid;
  final String id;
  const HarvestTabPage({super.key, required this.treeUuid, required this.id});

  @override
  State<HarvestTabPage> createState() => _HarvestTabPageState();
}

class _HarvestTabPageState extends State<HarvestTabPage> {
  Future<dynamic>? _statusFuture;
  Future<dynamic>? _recordsFuture;

  @override
  void initState() {
    super.initState();
    // simplified: no entry animation
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ── Status extraction (unchanged logic) ─────────────────────────────────────
  String _extractStatus(dynamic d) {
    try {
      if (d == null) return 'Unknown';
      if (d is Map) {
        if (d.containsKey('data')) {
          final inner = d['data'];
          if (inner is Map && inner.containsKey('flowering_status')) {
            return inner['flowering_status']?.toString() ?? 'Unknown';
          }
          return inner?.toString() ?? 'Unknown';
        }
        if (d.containsKey('flowering_status')) {
          return d['flowering_status']?.toString() ?? 'Unknown';
        }
        for (final v in d.values) {
          if (v is String) return v;
        }
        return 'Unknown';
      }
      if (d is List && d.isNotEmpty) return _extractStatus(d.first);
      return d.toString();
    } catch (_) {
      return 'Unknown';
    }
  }

  // ── Records extraction ───────────────────────────────────────────────────────
  List<dynamic> _extractRecords(dynamic data) {
    // Expect either { data: [ ... ] } or a top-level list
    if (data is Map) {
      if (data['data'] is List) return List<dynamic>.from(data['data']);
      if (data['data'] is Map && data['data']['harvest_records'] is List) {
        return List<dynamic>.from(data['data']['harvest_records']);
      }
      if (data['harvest_records'] is List) {
        return List<dynamic>.from(data['harvest_records']);
      }
      return [];
    }
    if (data is List) return data;
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: FutureBuilder<dynamic>(
        future:
            _statusFuture ??= TreeApi.getTreeFloweringStatus(widget.treeUuid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingView();
          }
          if (snapshot.hasError) {
            return _ErrorView(message: snapshot.error.toString());
          }

          final statusLabel = _extractStatus(snapshot.data);

          return CustomScrollView(
            slivers: [
              // ── Flowering status hero card ─────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _FloweringStatusCard(
                    status: statusLabel,
                    onEdit: () => _onEditStatus(statusLabel),
                  ),
                ),
              ),

              // ── Section header ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.mossGreen,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Harvest Records',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      _AddRecordButton(
                        onTap: () => _showAddRecordDialog(context),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Harvest records timeline ───────────────────────────────
              FutureBuilder<dynamic>(
                future:
                    _recordsFuture ??= TreeApi.fetchHarvestRecords(
                      id: widget.treeUuid,
                    ),
                builder: (context, recSnap) {
                  if (recSnap.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(child: _LoadingView());
                  }
                  if (recSnap.hasError) {
                    return SliverToBoxAdapter(
                      child: _ErrorView(message: recSnap.error.toString()),
                    );
                  }

                  final records = _extractRecords(recSnap.data);

                  if (records.isEmpty) {
                    return const SliverToBoxAdapter(child: _EmptyRecordsView());
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _TimelineRecordTile(
                          record: records[i],
                          isLast: i == records.length - 1,
                          index: i,
                          treeUuid: widget.treeUuid,
                          treeId: widget.id, // ✅ ADD THIS

                          onRefresh: () async {
                            // parent will refresh the records list
                            if (!mounted) return;
                            setState(() {
                              _recordsFuture = TreeApi.fetchHarvestRecords(
                                id: widget.treeUuid,
                              );
                            });
                          },
                        ),
                        childCount: records.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Edit status ─────────────────────────────────────────────────────────────
  Future<void> _onEditStatus(String current) async {
    final selected = await _showEditDialog(context, current);
    if (selected == null || selected.isEmpty) return;

    // Attempt to save observation to server. If it fails, fall back to local UI update.
    try {
      // Fetch active harvest and extract its uuid to include in the observation
      String? activeHarvestUuid;
      try {
        final dynamic active = await HarvestApi.fetchActiveHarvest();
        if (active is Map) {
          activeHarvestUuid =
              (active['uuid'] ?? active['harvest_uuid'] ?? active['id'])
                  ?.toString();
        }
      } catch (e) {
        // ignore - we'll surface a friendly error below if missing
        // ignore: avoid_print
        print('No active harvest found: $e');
      }

      if (activeHarvestUuid == null || activeHarvestUuid.isEmpty) {
        await Flushbar(
          message: 'No active harvest event found. Cannot save observation.',
          icon: const Icon(Icons.error, color: Colors.white),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          borderRadius: BorderRadius.circular(12),
          margin: const EdgeInsets.all(12),
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
        return;
      }

      final resp = await TreeApi.addTreeFloweringObservation(
        id: widget.treeUuid,
        floweringStatus: selected,
        harvestUuid: activeHarvestUuid,
      );
      // On success, refresh status from server response when available
      setState(() {
        _statusFuture = Future.value(resp);
      });
      await Flushbar(
        message: 'Flowering status updated',
        icon: const Icon(Icons.check_circle, color: Colors.white),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
        borderRadius: BorderRadius.circular(12),
        margin: const EdgeInsets.all(12),
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    } catch (e) {
      // Do not fallback to local. Show error and keep server state.
      // Log the error for debugging.
      // ignore: avoid_print
      print('⚠️ Failed to save flowering status: $e');
      await Flushbar(
        message: 'Cannot save flowering status',
        icon: const Icon(Icons.error, color: Colors.white),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
        borderRadius: BorderRadius.circular(12),
        margin: const EdgeInsets.all(12),
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    }
  }

  // ── Add record bottom sheet ──────────────────────────────────────────────────
  Future<void> _showAddRecordDialog(BuildContext context) async {
    final dateController = TextEditingController();
    final numController = TextEditingController();
    // final weightController = TextEditingController();
    bool spoilt = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.warmWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.grass_rounded,
                        color: AppColors.mossGreen,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Add Harvest Record',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _BottomSheetField(
                    controller: dateController,
                    label: 'Harvest date',
                    icon: Icons.calendar_today_outlined,
                    readOnly: true,
                    onTap: () async {
                      final initial =
                          DateTime.tryParse(dateController.text) ??
                          DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        // Store as date-only (YYYY-MM-DD) to avoid time portion
                        dateController.text =
                            picked.toIso8601String().split('T').first;
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _BottomSheetField(
                          controller: numController,
                          label: 'No. of fruits',
                          icon: Icons.format_list_numbered_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Spoilt toggle
                  GestureDetector(
                    onTap: () => setS(() => spoilt = !spoilt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color:
                            spoilt
                                ? AppColors.spoiltRed.withOpacity(0.08)
                                : AppColors.mintFoam,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              spoilt ? AppColors.spoiltRed : AppColors.divider,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            spoilt
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline_rounded,
                            color:
                                spoilt
                                    ? AppColors.spoiltRed
                                    : AppColors.mossGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            spoilt ? 'Marked as spoilt' : 'Not spoilt',
                            style: TextStyle(
                              color:
                                  spoilt
                                      ? AppColors.spoiltRed
                                      : AppColors.textMid,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Switch.adaptive(
                            value: spoilt,
                            onChanged: (v) => setS(() => spoilt = v),
                            activeColor: AppColors.spoiltRed,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: AppColors.textMid),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.leafGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () async {
                          final date =
                              dateController.text.isNotEmpty
                                  ? dateController.text
                                  : null;
                          final num = int.tryParse(numController.text);
                          // final weight = double.tryParse(weightController.text);
                          Navigator.pop(context);

                          try {
                            // Fetch active harvest and extract its uuid
                            String? activeHarvestUuid;
                            try {
                              final dynamic active =
                                  await HarvestApi.fetchActiveHarvest();
                              if (active is Map) {
                                activeHarvestUuid =
                                    (active['uuid'] ??
                                            active['harvest_uuid'] ??
                                            active['id'])
                                        ?.toString();
                              } else if (active is List && active.isNotEmpty) {
                                final a = active.first;
                                if (a is Map) {
                                  activeHarvestUuid =
                                      (a['uuid'] ??
                                              a['harvest_uuid'] ??
                                              a['id'])
                                          ?.toString();
                                }
                              }
                            } catch (e) {
                              // ignore - we'll show an error below if missing
                            }

                            if (activeHarvestUuid == null ||
                                activeHarvestUuid.isEmpty) {
                              await Flushbar(
                                message:
                                    'No active harvest event found. Cannot save record.',
                                icon: const Icon(
                                  Icons.error,
                                  color: Colors.white,
                                ),
                                backgroundColor: Colors.red.shade700,
                                duration: const Duration(seconds: 3),
                                borderRadius: BorderRadius.circular(12),
                                margin: const EdgeInsets.all(12),
                                flushbarPosition: FlushbarPosition.TOP,
                              ).show(this.context);
                              return;
                            }

                            // Resolve server numeric tree ID: prefer widget.id (server-provided),
                            // otherwise fetch from API using the UUID. This must be a numeric id.
                            String serverId = widget.id;
                            if (serverId.isEmpty ||
                                int.tryParse(serverId) == null) {
                              try {
                                final srv = await TreeApi.getTreeByUuid(
                                  widget.treeUuid,
                                );
                                Map<String, dynamic>? tmap;
                                if (srv.containsKey('data')) {
                                  final d = srv['data'];
                                  if (d is Map) {
                                    tmap = Map<String, dynamic>.from(d);
                                  }
                                } else {
                                  tmap = Map<String, dynamic>.from(srv);
                                }
                              
                                if (tmap != null && tmap.containsKey('id')) {
                                  final sid = tmap['id']?.toString();
                                  if (sid != null && sid.isNotEmpty) {
                                    serverId = sid;
                                  }
                                }
                              } catch (_) {}
                            }

                            // If we still don't have a numeric server id, abort — server expects numeric `id`.
                            if (serverId.isEmpty ||
                                int.tryParse(serverId) == null) {
                              await Flushbar(
                                message:
                                    'Could not resolve server numeric tree id. Cannot save record.',
                                icon: const Icon(
                                  Icons.error,
                                  color: Colors.white,
                                ),
                                backgroundColor: Colors.red.shade700,
                                duration: const Duration(seconds: 3),
                                borderRadius: BorderRadius.circular(12),
                                margin: const EdgeInsets.all(12),
                                flushbarPosition: FlushbarPosition.TOP,
                              ).show(this.context);
                              return;
                            }

                            await HarvestApi.createHarvestRecord(
                              treeId: serverId,
                              harvestUuid: activeHarvestUuid,
                              harvestDate: date,
                              numOfFruits: num,
                              // weight: weight,
                              spoilt: spoilt,
                            );

                            // Refresh using the server numeric id (required by backend)
                            setState(() {
                              _recordsFuture = TreeApi.fetchHarvestRecords(
                                id: serverId,
                              );
                            });

                            await Flushbar(
                              message: 'Record saved',
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                              ),
                              backgroundColor: Colors.green.shade700,
                              duration: const Duration(seconds: 2),
                              borderRadius: BorderRadius.circular(12),
                              margin: const EdgeInsets.all(12),
                              flushbarPosition: FlushbarPosition.TOP,
                            ).show(this.context);
                          } catch (e) {
                            await Flushbar(
                              message: 'Failed: $e',
                              backgroundColor: Colors.red.shade700,
                              duration: const Duration(seconds: 3),
                              flushbarPosition: FlushbarPosition.BOTTOM,
                            ).show(this.context);
                          }
                        },
                        child: const Text('Save record'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Edit flowering status sheet ─────────────────────────────────────────────
  Future<String?> _showEditDialog(BuildContext context, String current) {
    final options = ['A', 'B', 'C', 'D', 'X'];
    String selected =
        options.contains(current.toUpperCase())
            ? current.toUpperCase()
            : options.first;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setS) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.warmWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.local_florist_rounded,
                        color: AppColors.mossGreen,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Flowering Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children:
                        options.map((s) {
                          final isSelected = s == selected;
                          return GestureDetector(
                            onTap: () => setS(() => selected = s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? _HarvestTheme.statusColor(s)
                                        : AppColors.mintFoam,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? _HarvestTheme.statusColor(s)
                                          : AppColors.divider,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow:
                                    isSelected
                                        ? [
                                          BoxShadow(
                                            color: _HarvestTheme.statusColor(
                                              s,
                                            ).withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                        : [],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    s,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          isSelected
                                              ? _HarvestTheme.statusText(s)
                                              : AppColors.textMid,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _HarvestTheme.statusDescription(s),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          isSelected
                                              ? _HarvestTheme.statusText(
                                                s,
                                              ).withOpacity(0.85)
                                              : AppColors.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: AppColors.textMid),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.leafGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, selected),
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _FloweringStatusCard extends StatelessWidget {
  final String status;
  final VoidCallback onEdit;
  const _FloweringStatusCard({required this.status, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final color = _HarvestTheme.statusColor(status);
    final textColor = _HarvestTheme.statusText(status);
    final desc = _HarvestTheme.statusDescription(status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Colored accent strip + status badge
          Container(
            width: 80,
            height: 88,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Scale the status text down to fit available space
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    desc,
                    style: TextStyle(
                      fontSize: 10,
                      color: textColor.withOpacity(0.85),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Flowering Status',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.local_florist_rounded,
                      size: 16,
                      color: AppColors.mossGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          IconButton(
            tooltip: 'Edit flowering status',
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.mintFoam,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.edit_rounded,
                size: 18,
                color: AppColors.mossGreen,
              ),
            ),
            onPressed: onEdit,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _AddRecordButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddRecordButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.leafGreen,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.leafGreen.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            const Text(
              'Add',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRecordTile extends StatelessWidget {
  final dynamic record;
  final bool isLast;
  final int index;
  final String treeUuid;
  final String treeId;
  final Future<void> Function()? onRefresh;

  const _TimelineRecordTile({
    required this.record,
    required this.isLast,
    required this.index,
    required this.treeUuid,
    required this.treeId,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final rawDate = record['harvest_date']?.toString() ?? '';
    DateTime? date;
    if (rawDate.isNotEmpty) {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        date = parsed.toLocal(); // ✅ converts UTC → Malaysia time (UTC+8)
      }
    }

    final dateStr = date != null ? DateFormat.yMMMd().format(date) : '—';
    final dayStr = date != null ? DateFormat.d().format(date) : '—';
    final monStr =
        date != null ? DateFormat.MMM().format(date).toUpperCase() : '';
    final num = record['num_of_fruits']?.toString() ?? '—';
    // final weight = record['weight'] != null ? '${record['weight']} kg' : '—';
    final spoilt = record['spoilt'] == true;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 56,
                  decoration: BoxDecoration(
                    color:
                        spoilt
                            ? AppColors.spoiltRed.withOpacity(0.1)
                            : AppColors.mintFoam,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          spoilt
                              ? AppColors.spoiltRed.withOpacity(0.3)
                              : AppColors.divider,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayStr,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color:
                              spoilt ? AppColors.spoiltRed : AppColors.textDark,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        monStr,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color:
                              spoilt
                                  ? AppColors.spoiltRed.withOpacity(0.8)
                                  : AppColors.mossGreen,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(width: 2, color: AppColors.divider),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Record card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: GestureDetector(
                onTap: () async {
                  // Show options: Edit / Delete
                  // Use harvest_uuid (the harvest event UUID) to identify the record for update/delete
                  final harvestUuid = record['harvest_uuid']?.toString();
                  final recordId = record['id']?.toString();

                  // Debug: print the selected record and the identifier used for update/delete
                  try { // ignore: avoid_print
                    print('Selected harvest record: $record');
                    print('Edit harvest record - harvest_uuid: $harvestUuid, record id: $recordId');
                  } catch (_) {}

                  if (harvestUuid == null || harvestUuid.isEmpty) {
                    await Flushbar(
                      message: 'Cannot edit this harvest record: missing harvest_uuid',
                      icon: const Icon(Icons.error, color: Colors.white),
                      backgroundColor: Colors.red.shade700,
                      duration: const Duration(seconds: 3),
                      borderRadius: BorderRadius.circular(8),
                      margin: const EdgeInsets.all(12),
                      flushbarPosition: FlushbarPosition.TOP,
                    ).show(context);
                    return;
                  }
                  final harvestEventUuid = harvestUuid;
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    // ✅ This ensures the builder is only called once
                    builder:
                        (ctx) => _EditHarvestSheet(
                          record: record,
                          treeId: treeId,
                          harvestEventUuid: harvestEventUuid,
                          onRefresh: onRefresh,
                        ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color:
                          spoilt
                              ? AppColors.spoiltRed.withOpacity(0.2)
                              : AppColors.divider,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          if (spoilt)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.spoiltRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 12,
                                    color: AppColors.spoiltRed,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Spoilt',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.spoiltRed,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.eco_rounded,
                                size: 14,
                                color: AppColors.mossGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                num,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMid,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditHarvestSheet extends StatefulWidget {
  final dynamic record;
  final String treeId;
  final String harvestEventUuid;
  final Future<void> Function()? onRefresh;

  const _EditHarvestSheet({
    required this.record,
    required this.treeId,
    required this.harvestEventUuid,
    this.onRefresh,
  });

  @override
  State<_EditHarvestSheet> createState() => _EditHarvestSheetState();
}

class _EditHarvestSheetState extends State<_EditHarvestSheet> {
  late final TextEditingController dateController;
  late final TextEditingController numController;
  // late final TextEditingController weightController;
  late bool spoilt;

  @override
  void initState() {
    super.initState();
    final rawDate = widget.record['harvest_date']?.toString() ?? '';
    String dateOnly = '';
    if (rawDate.isNotEmpty) {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        final local = parsed.toLocal();
        dateOnly =
            '${local.year.toString().padLeft(4, '0')}-'
            '${local.month.toString().padLeft(2, '0')}-'
            '${local.day.toString().padLeft(2, '0')}';
      }
    }
    dateController = TextEditingController(text: dateOnly);
    numController = TextEditingController(
      text: widget.record['num_of_fruits']?.toString() ?? '',
    );
    // weightController = TextEditingController(
    //   text: widget.record['weight']?.toString() ?? '',
    // );
    spoilt = widget.record['spoilt'] == true;
  }

  @override
  void dispose() {
    dateController.dispose();
    numController.dispose();
    // weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.warmWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Edit harvest',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _BottomSheetField(
              controller: dateController,
              label: 'Harvest date',
              icon: Icons.calendar_today_outlined,
              readOnly: true,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      DateTime.tryParse(dateController.text) ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  // ✅ Just update controller text, no setState needed
                  dateController.text =
                      picked.toIso8601String().split('T').first;
                }
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _BottomSheetField(
                    controller: numController,
                    label: 'No. of fruits',
                    icon: Icons.format_list_numbered_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
                // const SizedBox(width: 8),
                // Expanded(
                //   child: _BottomSheetField(
                //     controller: weightController,
                //     label: 'Weight (kg)',
                //     icon: Icons.scale_outlined,
                //     keyboardType: const TextInputType.numberWithOptions(
                //       decimal: true,
                //     ),
                //   ),
                // ),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => spoilt = !spoilt),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color:
                      spoilt
                          ? AppColors.spoiltRed.withOpacity(0.08)
                          : AppColors.mintFoam,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: spoilt ? AppColors.spoiltRed : AppColors.divider,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      spoilt
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline_rounded,
                      color: spoilt ? AppColors.spoiltRed : AppColors.mossGreen,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      spoilt ? 'Marked as spoilt' : 'Not spoilt',
                      style: TextStyle(
                        color: spoilt ? AppColors.spoiltRed : AppColors.textMid,
                      ),
                    ),
                    const Spacer(),
                    Switch.adaptive(
                      value: spoilt,
                      onChanged: (v) => setState(() => spoilt = v),
                      activeColor: AppColors.spoiltRed,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textMid),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.leafGreen,
                  ),
                  onPressed: () async {
                    try {
                      await HarvestApi.updateHarvestRecord(
                        recordId: widget.record['id'].toString(),
                        harvestDate:
                            dateController.text.isNotEmpty
                                ? DateTime.parse(dateController.text)
                                : null,
                        numOfFruits: int.tryParse(numController.text),
                        // weight: double.tryParse(weightController.text),
                        spoilt: spoilt,
                      );
                      print("Record ID: ${widget.record['id']}, Harvest UUID: ${widget.harvestEventUuid}"); // Debug log
                      print("Updated values - Date: ${dateController.text}, Num of fruits: ${numController.text}, Spoilt: $spoilt"); // Debug log
                      if (widget.onRefresh != null) await widget.onRefresh!();
                      if (!mounted) return;
                      await Flushbar(
                        message: 'Record updated',
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                        ),
                        backgroundColor: Colors.green.shade700,
                        duration: const Duration(seconds: 2),
                        borderRadius: BorderRadius.circular(12),
                        margin: const EdgeInsets.all(12),
                        flushbarPosition: FlushbarPosition.TOP,
                      ).show(context);
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      // ignore: avoid_print
                      print('⚠️ Failed to update harvest record: $e');
                      // ignore: avoid_print
                      print(StackTrace.current);
                      if (!mounted) return;
                      await Flushbar(
                        message: 'Update failed: $e',
                        icon: const Icon(Icons.error, color: Colors.white),
                        backgroundColor: Colors.red.shade700,
                        duration: const Duration(seconds: 3),
                        borderRadius: BorderRadius.circular(8),
                        margin: const EdgeInsets.all(12),
                        flushbarPosition: FlushbarPosition.TOP,
                      ).show(context);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder:
                            (dctx) => AlertDialog(
                              title: const Text('Confirm delete'),
                              content: const Text(
                                'Delete this harvest record?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(dctx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(dctx).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                      );
                      if (confirm == true) {
                        Navigator.pop(context);
                        try {
                          await HarvestApi.deleteHarvestRecord(
                            recordId: widget.record['id'].toString(),
                          );
                          if (widget.onRefresh != null) {
                            await widget.onRefresh!();
                          }
                          await Flushbar(
                            message: 'Record deleted',
                            icon: const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                            ),
                            backgroundColor: Colors.green.shade700,
                            duration: const Duration(seconds: 2),
                            borderRadius: BorderRadius.circular(12),
                            margin: const EdgeInsets.all(12),
                            flushbarPosition: FlushbarPosition.TOP,
                          ).show(context);
                        } catch (e) {
                          await Flushbar(
                            message: 'Delete failed: $e',
                            icon: const Icon(Icons.error, color: Colors.white),
                            backgroundColor: Colors.red.shade700,
                            duration: const Duration(seconds: 3),
                            borderRadius: BorderRadius.circular(8),
                            margin: const EdgeInsets.all(12),
                            flushbarPosition: FlushbarPosition.TOP,
                          ).show(context);
                        }
                      }
                    },
                    child: const Text('Delete record'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;

  const _BottomSheetField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.mossGreen, width: 1.5),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(
        child: CircularProgressIndicator(color: AppColors.mossGreen),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: AppColors.spoiltRed,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMid, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecordsView extends StatelessWidget {
  const _EmptyRecordsView();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.mintFoam,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.eco_rounded,
              size: 36,
              color: AppColors.mossGreen,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No harvest records yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "Add" to log the first harvest for this tree.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}
