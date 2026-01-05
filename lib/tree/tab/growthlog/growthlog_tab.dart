import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/tree_growth_api.dart';
import 'package:fyp_hbs/models/tree_growth_model.dart';
import 'package:fyp_hbs/services/local database/growth_db.dart';
import 'package:another_flushbar/flushbar.dart';

class GrowthLogTabPage extends StatefulWidget {
  final String treeUuid;
  final VoidCallback? onGrowthLogSaved;
  const GrowthLogTabPage({super.key, required this.treeUuid, this.onGrowthLogSaved});

  @override
  State<GrowthLogTabPage> createState() => _GrowthLogTabPageState();
}

class _GrowthLogTabPageState extends State<GrowthLogTabPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int selectedTab = 0;

  List<FlSpot> heightData = [];
  List<FlSpot> diameterData = [];
  List<String> xLabels = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      setState(() {
        selectedTab = _tabController.index;
      });
    });

    _fetchGrowthLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchGrowthLogs() async {
    List<Map<String, dynamic>> logs = [];
    try {
      final remote = await TreeGrowthApi.fetchGrowthLogsByUuid(widget.treeUuid);
      logs = List<Map<String, dynamic>>.from(remote);
    } catch (e) {
      print("⚠️ Remote growth fetch failed, falling back to local DB: $e");
      try {
        final local = await GrowthDB().fetchAllGrowths(treeUuid: widget.treeUuid);
        logs = local.map((m) => m.toMap()).toList();
      } catch (localErr) {
        print("⚠️ Failed to load local growth logs: $localErr");
      }
    }

    try {
      List<FlSpot> heights = [];
      List<FlSpot> diameters = [];
      List<String> labels = [];

      for (int i = 0; i < logs.length; i++) {
        final log = logs[i];

        final rawHeight = log["height"];
        final double heightValue =
            rawHeight == null
                ? 0.0
                : (rawHeight is num
                    ? rawHeight.toDouble()
                    : double.tryParse(rawHeight.toString()) ?? 0.0);

        final rawDiameter = log["diameter"];
        final double diameterValue =
            rawDiameter == null
                ? 0.0
                : (rawDiameter is num
                    ? rawDiameter.toDouble()
                    : double.tryParse(rawDiameter.toString()) ?? 0.0);

        heights.add(FlSpot(i.toDouble(), heightValue));
        diameters.add(FlSpot(i.toDouble(), diameterValue));

        if (log["created_at"] != null) {
          final date = DateTime.tryParse(log["created_at"]);
          if (date != null) {
            labels.add("${date.month}/${date.year}");
          } else {
            labels.add("Log ${i + 1}");
          }
        } else {
          labels.add("Log ${i + 1}");
        }
      }

      if (!mounted) return;
      setState(() {
        heightData = heights;
        diameterData = diameters;
        xLabels = labels;
        isLoading = false;
      });
    } catch (e) {
      print("Error processing growth logs: $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showAddGrowthDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final TextEditingController heightController = TextEditingController();
        final TextEditingController diameterController = TextEditingController();

        return Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.hunterGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.add_chart,
                      color: AppColors.hunterGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Add Growth Log",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.hunterGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Height field
              TextField(
                controller: heightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "Height (cm)",
                  prefixIcon: Icon(Icons.height, color: AppColors.hunterGreen),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.hunterGreen, width: 2),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                ),
              ),
              const SizedBox(height: 16),

              // Diameter field
              TextField(
                controller: diameterController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "Diameter (cm)",
                  prefixIcon: Icon(Icons.circle_outlined, color: AppColors.hunterGreen),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.hunterGreen, width: 2),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(bottomSheetContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppColors.gray400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.hunterGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final height = heightController.text.trim();
                        final diameter = diameterController.text.trim();
                        
                        if (height.isEmpty || diameter.isEmpty) {
                          await Flushbar(
                            message: 'Please enter both height and diameter',
                            backgroundColor: Colors.orange.shade700,
                            duration: const Duration(seconds: 2),
                            margin: const EdgeInsets.all(12),
                            borderRadius: BorderRadius.circular(8),
                          ).show(bottomSheetContext);
                          return;
                        }

                        try {
                          await TreeGrowthApi.addGrowthLog(
                            treeUuid: widget.treeUuid,
                            height: double.parse(height),
                            diameter: double.parse(diameter),
                          );

                          if (mounted) {
                            Navigator.pop(bottomSheetContext);
                            await _fetchGrowthLogs();
                            widget.onGrowthLogSaved?.call();
                            await Flushbar(
                              message: 'Growth log added successfully',
                              icon: const Icon(Icons.check_circle, color: Colors.white),
                              backgroundColor: Colors.green.shade700,
                              duration: const Duration(seconds: 2),
                              margin: const EdgeInsets.all(12),
                              borderRadius: BorderRadius.circular(8),
                            ).show(context);
                          }
                        } catch (e) {
                          print("⚠️ Remote add failed, saving growth locally: $e");
                          try {
                            final localUuid = 'local_${DateTime.now().millisecondsSinceEpoch}';
                            final g = TreeGrowthModel(
                              uuid: localUuid,
                              treeUuid: widget.treeUuid,
                              height: double.tryParse(height) ?? 0.0,
                              diameter: double.tryParse(diameter) ?? 0.0,
                              createdAt: DateTime.now().toIso8601String(),
                              synced: 0,
                            );
                            await GrowthDB().insertGrowth(g);
                            if (mounted) {
                              Navigator.pop(bottomSheetContext);
                              await _fetchGrowthLogs();
                              widget.onGrowthLogSaved?.call();
                              await Flushbar(
                                message: 'Saved locally, will sync when online',
                                icon: const Icon(Icons.cloud_off, color: Colors.white),
                                backgroundColor: Colors.orange.shade700,
                                duration: const Duration(seconds: 2),
                                margin: const EdgeInsets.all(12),
                                borderRadius: BorderRadius.circular(8),
                              ).show(context);
                            }
                          } catch (localErr) {
                            print('Failed to save growth locally: $localErr');
                            if (mounted) {
                              Navigator.pop(bottomSheetContext);
                              await Flushbar(
                                message: 'Failed to save growth log',
                                backgroundColor: Colors.red.shade700,
                                duration: const Duration(seconds: 3),
                                margin: const EdgeInsets.all(12),
                                borderRadius: BorderRadius.circular(8),
                              ).show(context);
                            }
                          }
                        }
                      },
                      child: const Text(
                        "Save Log",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gray300, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _tabController.animateTo(0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selectedTab == 0
                                  ? AppColors.hunterGreen
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.height,
                                  size: 18,
                                  color: selectedTab == 0
                                      ? Colors.white
                                      : AppColors.gray600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Height",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: selectedTab == 0
                                        ? Colors.white
                                        : AppColors.gray600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _tabController.animateTo(1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selectedTab == 1
                                  ? AppColors.hunterGreen
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.circle_outlined,
                                  size: 18,
                                  color: selectedTab == 1
                                      ? Colors.white
                                      : AppColors.gray600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Diameter",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: selectedTab == 1
                                        ? Colors.white
                                        : AppColors.gray600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.hunterGreen, AppColors.mossGreen],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.hunterGreen.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white, size: 24),
                  onPressed: _showAddGrowthDialog,
                ),
              ),
            ],
          ),
        ),

        // Chart area
        Expanded(
          child: isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: AppColors.hunterGreen,
                  ),
                )
              : heightData.isEmpty && diameterData.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.show_chart,
                              size: 64,
                              color: AppColors.gray400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No growth data yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.gray600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add your first growth measurement to track progress',
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
                  : heightData.length < 2 || diameterData.length < 2
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.timeline,
                                  size: 64,
                                  color: AppColors.gray400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Need more data points',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.gray600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add at least 2 measurements to see the growth chart',
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
                      : Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.gray300,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Chart title
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.hunterGreen.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      selectedTab == 0 ? Icons.height : Icons.circle_outlined,
                                      color: AppColors.hunterGreen,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedTab == 0 ? 'Height Growth' : 'Diameter Growth',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.hunterGreen,
                                        ),
                                      ),
                                      Text(
                                        'Over time (m)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.gray600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              
                              // Chart
                              Expanded(
                                child: LineChart(
                                  LineChartData(
                                    minX: 0,
                                    maxX: xLabels.isNotEmpty
                                        ? (xLabels.length - 1).toDouble()
                                        : 0,
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: true,
                                      horizontalInterval: 1,
                                      verticalInterval: 1,
                                      getDrawingHorizontalLine: (value) {
                                        return FlLine(
                                          color: AppColors.gray300,
                                          strokeWidth: 1,
                                          dashArray: [5, 5],
                                        );
                                      },
                                      getDrawingVerticalLine: (value) {
                                        return FlLine(
                                          color: AppColors.gray300,
                                          strokeWidth: 1,
                                          dashArray: [5, 5],
                                        );
                                      },
                                    ),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      topTitles: AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      rightTitles: AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 45,
                                          getTitlesWidget: (value, meta) {
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 8),
                                              child: Text(
                                                value.toInt().toString(),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.gray600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 40,
                                          interval: 1,
                                          getTitlesWidget: (value, meta) {
                                            final index = value.toInt();
                                            if (index >= 0 && index < xLabels.length) {
                                              // Show every other label if there are many data points
                                              if (xLabels.length > 6 && index % 2 != 0) {
                                                return const SizedBox.shrink();
                                              }
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 8),
                                                child: Transform.rotate(
                                                  angle: -0.5,
                                                  child: Text(
                                                    xLabels[index],
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors.gray600,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(
                                      show: true,
                                      border: Border(
                                        bottom: BorderSide(
                                          color: AppColors.gray400,
                                          width: 2,
                                        ),
                                        left: BorderSide(
                                          color: AppColors.gray400,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: selectedTab == 0 ? heightData : diameterData,
                                        isCurved: true,
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.hunterGreen,
                                            AppColors.mossGreen,
                                          ],
                                        ),
                                        barWidth: 4,
                                        isStrokeCapRound: true,
                                        dotData: FlDotData(
                                          show: true,
                                          getDotPainter: (spot, percent, barData, index) {
                                            return FlDotCirclePainter(
                                              radius: 6,
                                              color: Colors.white,
                                              strokeWidth: 3,
                                              strokeColor: AppColors.hunterGreen,
                                            );
                                          },
                                        ),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.hunterGreen.withOpacity(0.2),
                                              AppColors.mossGreen.withOpacity(0.05),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                    ],
                                    lineTouchData: LineTouchData(
                                      touchTooltipData: LineTouchTooltipData(
                                        tooltipBgColor: AppColors.hunterGreen,
                                        tooltipRoundedRadius: 8,
                                        getTooltipItems: (touchedSpots) {
                                          return touchedSpots.map((spot) {
                                            return LineTooltipItem(
                                              '${spot.y.toStringAsFixed(1)} cm',
                                              const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            );
                                          }).toList();
                                        },
                                      ),
                                      handleBuiltInTouches: true,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
        ),
      ],
    );
  }
}