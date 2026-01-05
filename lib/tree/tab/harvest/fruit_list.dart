import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/tree_api.dart';
import 'package:fyp_hbs/services/local database/fruit_db.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:intl/intl.dart';
import 'package:fyp_hbs/fruit/create_fruit.dart';

class FruitListPage extends StatefulWidget {
  final String treeUuid;
  final String? harvestUuid;

  const FruitListPage({super.key, required this.treeUuid, this.harvestUuid});

  @override
  State<FruitListPage> createState() => _FruitPageState();
}

class _FruitPageState extends State<FruitListPage> {
  List<Map<String, dynamic>> _harvestEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchHarvestEvents();
  }

  Future<void> fetchHarvestEvents() async {
    try {
      final events = await TreeApi.getHarvestsByTreeId(widget.treeUuid);

      if (widget.harvestUuid != null && widget.harvestUuid!.isNotEmpty) {
        final String target = widget.harvestUuid!;
        Map<String, dynamic>? matched;
        
        for (final ev in events) {
          final evUuid = (ev['uuid'] ?? ev['id'] ?? ev['harvest_uuid'])?.toString();
          if (evUuid == target) {
            matched = Map<String, dynamic>.from(ev);
            break;
          }
          if (ev['fruits'] is List) {
            final list = List.from(ev['fruits']);
            if (list.any((f) => (f['harvest_uuid'] ?? '') == target || (f['tree_uuid'] ?? '') == widget.treeUuid)) {
              matched = Map<String, dynamic>.from(ev);
              break;
            }
          }
        }

        if (matched != null) {
          List<Map<String, dynamic>> fruits = [];
          if (matched['fruits'] is List) {
            for (final f in matched['fruits']) {
              if ((f['tree_uuid'] ?? '') == widget.treeUuid || (f['harvest_uuid'] ?? '') == target) {
                fruits.add(Map<String, dynamic>.from(f));
              }
            }
          }

          if (fruits.isEmpty) {
            final local = await FruitDB().getAllFruits();
            final localMatches = local.where((f) => (f.harvest_uuid ?? '') == target && (f.tree_uuid ?? '') == widget.treeUuid).toList();
            for (final lm in localMatches) fruits.add(lm.toMap());
          }

          final matchedNonNull = matched;
          if (mounted) {
            setState(() {
              _harvestEvents = [
                {
                  'uuid': widget.harvestUuid,
                  'event_name': matchedNonNull['event_name'] ?? 'Harvest ${widget.harvestUuid}',
                  'start_date': matchedNonNull['start_date'] ?? '',
                  'end_date': matchedNonNull['end_date'] ?? '',
                  'fruits': fruits,
                }
              ];
              _isLoading = false;
            });
          }
          return;
        }

        final local = await FruitDB().getAllFruits();
        final localMatches = local.where((f) => (f.harvest_uuid ?? '') == widget.harvestUuid && (f.tree_uuid ?? '') == widget.treeUuid).toList();
        if (localMatches.isNotEmpty && mounted) {
          setState(() {
            _harvestEvents = [
              {
                'uuid': widget.harvestUuid,
                'event_name': 'Cached harvest ${widget.harvestUuid?.substring(0, widget.harvestUuid!.length > 8 ? 8 : widget.harvestUuid!.length) ?? ''}',
                'start_date': localMatches.first.harvested_at ?? '',
                'end_date': localMatches.first.harvested_at ?? '',
                'fruits': localMatches.map((f) => f.toMap()).toList(),
              }
            ];
            _isLoading = false;
          });
          return;
        }
      }

      if (mounted) {
        setState(() {
          _harvestEvents = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      try {
        if (widget.harvestUuid != null && widget.harvestUuid!.isNotEmpty) {
          final local = await FruitDB().getAllFruits();
          final localMatches = local.where((f) => (f.harvest_uuid ?? '') == widget.harvestUuid && (f.tree_uuid ?? '') == widget.treeUuid).toList();
          if (localMatches.isNotEmpty && mounted) {
            setState(() {
              _harvestEvents = [
                {
                  'uuid': widget.harvestUuid,
                  'event_name': 'Cached harvest ${widget.harvestUuid?.substring(0, widget.harvestUuid!.length > 8 ? 8 : widget.harvestUuid!.length) ?? ''}',
                  'start_date': localMatches.first.harvested_at ?? '',
                  'end_date': localMatches.first.harvested_at ?? '',
                  'fruits': localMatches.map((f) => f.toMap()).toList(),
                }
              ];
              _isLoading = false;
            });
            return;
          }
        }

        final localAll = await FruitDB().fetchFruitsByTree(widget.treeUuid);
        if (localAll.isEmpty) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _harvestEvents = [];
            });
            await Flushbar(
              message: "Offline: no cached fruits found: $e",
              backgroundColor: Colors.orange.shade700,
              duration: const Duration(seconds: 3),
              margin: const EdgeInsets.all(12),
              borderRadius: BorderRadius.circular(8),
            ).show(context);
          }
          return;
        }

        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (final f in localAll) {
          final h = f.harvest_uuid ?? 'unknown';
          grouped.putIfAbsent(h, () => []).add(f.toMap());
        }

        final events = <Map<String, dynamic>>[];
        grouped.forEach((harvestUuid, items) {
          events.add({
            'uuid': harvestUuid,
            'event_name': 'Cached harvest ${harvestUuid.substring(0, harvestUuid.length > 8 ? 8 : harvestUuid.length)}',
            'start_date': items.first['harvested_at'] ?? '',
            'end_date': items.first['harvested_at'] ?? '',
            'fruits': items,
          });
        });

        if (mounted) {
          setState(() {
            _harvestEvents = events;
            _isLoading = false;
          });
        }
      } catch (localErr) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          await Flushbar(
            message: "Error loading harvest events: $e | $localErr",
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(12),
            borderRadius: BorderRadius.circular(8),
          ).show(context);
        }
      }
    }
  }

  String _formatDateRange(String? startDate, String? endDate) {
    if (startDate == null || startDate.isEmpty) return 'Date not available';
    
    try {
      final start = DateTime.parse(startDate);
      final fmt = DateFormat('MMM dd');
      
      if (endDate == null || endDate.isEmpty || endDate == 'Ongoing') {
        return '${fmt.format(start)}, ${start.year} - Ongoing';
      }
      
      final end = DateTime.parse(endDate);
      
      if (start.month == end.month && start.year == end.year) {
        return '${DateFormat('MMM').format(start)} ${start.day}-${end.day}, ${start.year}';
      }
      
      if (start.year == end.year) {
        return '${fmt.format(start)} - ${fmt.format(end)}, ${start.year}';
      }
      
      return '${fmt.format(start)}, ${start.year} - ${fmt.format(end)}, ${end.year}';
    } catch (e) {
      return startDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Harvest Fruits',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.pakistanGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppColors.hunterGreen,
                ),
              )
            : _harvestEvents.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: AppColors.gray400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No fruits found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gray600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Fruits from this harvest will appear here',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.gray500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _harvestEvents.length,
                    itemBuilder: (context, index) {
                      final event = _harvestEvents[index];
                      final fruits = List<Map<String, dynamic>>.from(event['fruits']);
                      final dateRange = _formatDateRange(event['start_date'], event['end_date']);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.gray300,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.hunterGreen.withOpacity(0.1),
                                    AppColors.mossGreen.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.hunterGreen.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.agriculture,
                                          color: AppColors.hunterGreen,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          event['event_name'] ?? 'Unnamed Event',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: AppColors.hunterGreen,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 14,
                                        color: AppColors.gray600,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          dateRange,
                                          style: TextStyle(
                                            color: AppColors.gray600,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.inventory_2_outlined,
                                        size: 14,
                                        color: AppColors.gray600,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${fruits.length} ${fruits.length == 1 ? 'fruit' : 'fruits'} collected',
                                        style: TextStyle(
                                          color: AppColors.gray600,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Fruits List
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: fruits.map((fruit) => _buildFruitCard(fruit)).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildFruitCard(Map<String, dynamic> fruit) {
    final String tag = fruit['fruit_tag'] ?? 'Unknown';
    final String weight = fruit['weight']?.toString() ?? 'Unknown';
    final String grade = fruit['grade'] ?? 'Unknown';
    final String uuid = (fruit['uuid'] ?? fruit['id'] ?? fruit['harvest_uuid'] ?? '').toString();
    final bool isSpoiled = fruit['is_spoiled'] == true || 
                           fruit['is_spoiled'] == 1 || 
                           fruit['is_spoiled']?.toString() == 'true';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.gray300,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () => _showFruitDetailsDialog(context, fruit),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // QR Code
              Container(
                width: 60,
                height: 60,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.gray300,
                    width: 1,
                  ),
                ),
                child: uuid.isNotEmpty
                    ? QrImageView(data: uuid, version: QrVersions.auto)
                    : Icon(Icons.local_florist, color: AppColors.hunterGreen),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.hunterGreen,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.scale,
                          size: 13,
                          color: AppColors.gray500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "$weight kg",
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.gray600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.grade,
                          size: 13,
                          color: AppColors.gray500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Grade $grade",
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.gray600,
                          ),
                        ),
                      ],
                    ),
                    if (isSpoiled) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 13,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Spoiled',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // View Button
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.hunterGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.hunterGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFruitDetailsDialog(BuildContext context, Map<String, dynamic> fruit) {
    final String uuid = fruit['uuid'] ?? '';
    final String tag = fruit['fruit_tag'] ?? 'Unknown';
    final String date = fruit['harvested_at'] ?? '';
    final String weight = fruit['weight']?.toString() ?? '';
    final String grade = fruit['grade'] ?? '';
    final String? transactionId = fruit['transaction_uuid'];
    final bool isSpoiled = fruit['is_spoiled'] == true || 
                           fruit['is_spoiled'] == 1 || 
                           fruit['is_spoiled']?.toString() == 'true';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.hunterGreen, AppColors.mossGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      const Text(
                        'Fruit Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateFruitPage(fruit: fruit),
                            ),
                          );
                          if (result == true) {
                            await fetchHarvestEvents();
                          }
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // QR Code
                        GestureDetector(
                          onTap: () {
                            if (uuid.isEmpty) return;
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                backgroundColor: Colors.transparent,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
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
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.gray300, width: 1.5),
                            ),
                            child: Column(
                              children: [
                                QrImageView(
                                  data: uuid,
                                  version: QrVersions.auto,
                                  size: 140,
                                  gapless: true,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.gray200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    uuid,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.gray600,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title
                        Text(
                          tag,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: AppColors.hunterGreen,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Status Badges
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (transactionId != null)
                              _buildStatusBadge(
                                'Sold',
                                Icons.check_circle,
                                AppColors.warningActive,
                                AppColors.hunterGreen,
                              ),
                            if (transactionId != null && isSpoiled)
                              const SizedBox(width: 8),
                            if (isSpoiled)
                              _buildStatusBadge(
                                'Spoiled',
                                Icons.warning_amber_rounded,
                                Colors.red.withOpacity(0.1),
                                Colors.red.shade700,
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Details Card
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.gray300, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              _buildDetailRow(
                                Icons.calendar_today,
                                'Harvest Date',
                                date.isNotEmpty 
                                    ? DateFormat('MMM dd, yyyy').format(DateTime.parse(date))
                                    : 'N/A',
                                isFirst: true,
                              ),
                              const Divider(height: 1, thickness: 1),
                              _buildDetailRow(
                                Icons.scale,
                                'Weight',
                                weight.isNotEmpty ? '$weight kg' : 'N/A',
                              ),
                              const Divider(height: 1, thickness: 1),
                              _buildDetailRow(
                                Icons.grade,
                                'Grade',
                                grade.isNotEmpty ? 'Grade $grade' : 'N/A',
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String label, IconData icon, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isFirst = false, bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.hunterGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.hunterGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}