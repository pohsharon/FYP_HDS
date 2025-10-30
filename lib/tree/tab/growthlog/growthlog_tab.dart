import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/tree_growth_api.dart';

class GrowthLogTabPage extends StatefulWidget {
  final String treeUuid;
  const GrowthLogTabPage({super.key, required this.treeUuid});

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
      setState(() {
        selectedTab = _tabController.index;
      });
    });

    _fetchGrowthLogs();
  }

  Future<void> _fetchGrowthLogs() async {
    try {
      final logs = await TreeGrowthApi.fetchGrowthLogsByUuid(widget.treeUuid);

      List<FlSpot> heights = [];
      List<FlSpot> diameters = [];
      List<String> labels = [];

      for (int i = 0; i < logs.length; i++) {
        final log = logs[i];

        // parse height
        final rawHeight = log["height"];
        final double heightValue =
            rawHeight == null
                ? 0.0
                : (rawHeight is num
                    ? rawHeight.toDouble()
                    : double.tryParse(rawHeight.toString()) ?? 0.0);

        // parse diameter
        final rawDiameter = log["diameter"];
        final double diameterValue =
            rawDiameter == null
                ? 0.0
                : (rawDiameter is num
                    ? rawDiameter.toDouble()
                    : double.tryParse(rawDiameter.toString()) ?? 0.0);

        heights.add(FlSpot(i.toDouble(), heightValue));
        diameters.add(FlSpot(i.toDouble(), diameterValue));

        // parse date → Month/Year
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

      setState(() {
        heightData = heights;
        diameterData = diameters;
        xLabels = labels;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching growth logs: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prepare axis helpers
    // Determine which x-label indices to show (only first occurrence per month/year)
    final Map<String, int> _firstIndexForLabel = {};
    for (int i = 0; i < xLabels.length; i++) {
      _firstIndexForLabel.putIfAbsent(xLabels[i], () => i);
    }
    

    // Determine Y axis formatting based on currently selected tab
    final List<FlSpot> displayedSpots = selectedTab == 0 ? heightData : diameterData;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final s in displayedSpots) {
      if (s.y.isNaN) continue;
      if (s.y < minY) minY = s.y;
      if (s.y > maxY) maxY = s.y;
    }
    if (minY == double.infinity || maxY == double.negativeInfinity) {
      minY = 0;
      maxY = 1;
    }

    // Add padding when min==max or small range
    double ySpan = (maxY - minY);
    if (ySpan == 0) {
      ySpan = maxY == 0 ? 1.0 : maxY * 0.1;
    }
    final yPadding = ySpan * 0.12;
    minY = max(0, minY - yPadding);
    maxY = maxY + yPadding;

    // Decide decimal places: if any value has fractional part -> show 1 decimal, else 0
    int yDecimals = 0;
    for (final s in displayedSpots) {
      if ((s.y - s.y.truncateToDouble()).abs() > 1e-9) {
        yDecimals = 1;
        break;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // Center everything
            children: [
              ToggleButtons(
                borderRadius: BorderRadius.circular(30),
                fillColor: AppColors.hunterGreen,
                selectedColor: Colors.white,
                color: AppColors.gray600,
                selectedBorderColor: AppColors.hunterGreen,
                constraints: const BoxConstraints(minHeight: 30, minWidth: 100),
                isSelected: [
                  _tabController.index == 0,
                  _tabController.index == 1,
                ],
                onPressed: (index) {
                  setState(() {
                    _tabController.animateTo(index);
                  });
                },
                children: const [
                  Text("Height", style: TextStyle(fontSize: 12)),
                  Text("Diameter", style: TextStyle(fontSize: 12)),
                ],
              ),

              const SizedBox(width: 8),

              // Smaller circle button
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.hunterGreen,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (context) {
                        final TextEditingController heightController =
                            TextEditingController();
                        final TextEditingController diameterController =
                            TextEditingController();

                        return Padding(
                          padding: EdgeInsets.only(
                            left: 30,
                            right: 30,
                            top: 20,
                            bottom:
                                MediaQuery.of(context).viewInsets.bottom + 20,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Add Growth Log",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Height field
                              TextField(
                                controller: heightController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "Height (cm)",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Diameter field
                              TextField(
                                controller: diameterController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "Diameter (cm)",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Save button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.hunterGreen,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final height = heightController.text.trim();
                                    final diameter =
                                        diameterController.text.trim();
                                    if (height.isNotEmpty && diameter.isNotEmpty) {
                                      try {
                                        await TreeGrowthApi.addGrowthLog(
                                          treeUuid: widget.treeUuid,
                                          height: double.parse(height),
                                          diameter: double.parse(diameter),
                                        );

                                        Navigator.pop(context, true);
                                        await _fetchGrowthLogs();
                                        setState(() {});
                                      } catch (e) {
                                        print("Error: $e");
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              "Failed to save growth log: $e",
                                            ),
                                          ),
                                        );
                                      }
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Please enter height and diameter",
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text("Save"),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Chart
        Expanded(
          child:
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : heightData.isEmpty && diameterData.isEmpty
                  ? const Center(child: Text("No growth logs yet"))
                  : Padding(
                    padding: const EdgeInsets.all(24),
                    child: // Build labels from your fetched logs
                        LineChart(
                      LineChartData(
            minX: 0,
            maxX: xLabels.length > 0 ? (xLabels.length - 1).toDouble() : 0,
            minY: minY,
            maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          getDrawingHorizontalLine:
                              (value) => FlLine(
                                strokeWidth: 0.5,
                                color: AppColors.gray300,
                              ),
                          getDrawingVerticalLine:
                              (value) => FlLine(
                                strokeWidth: 0.5,
                                color: AppColors.gray300,
                              ),
                        ),

                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            axisNameWidget: const Text(
                              "Date (Month/Year)",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            axisNameSize: 22,
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < xLabels.length && _firstIndexForLabel[xLabels[index]] == index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      xLabels[index],
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            axisNameWidget: Text(
                              selectedTab == 0
                                  ? "Height (cm)"
                                  : "Diameter (cm)",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            axisNameSize: 30,
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toStringAsFixed(yDecimals),
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w400,
                                  ),
                                );
                              },
                            ),
                          ),
                          // Hide top & right completely
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),

                        // Only bottom & left borders
                        borderData: FlBorderData(
                          show: true,
                          border: const Border(
                            bottom: BorderSide(color: Colors.black, width: 1),
                            left: BorderSide(color: Colors.black, width: 1),
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBgColor: Colors.white.withOpacity(0.9),
                            tooltipRoundedRadius: 12,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                return LineTooltipItem(
                                  "Month: ${xLabels[spot.x.toInt()]}\nValue: ${spot.y}",
                                  const TextStyle(color: Colors.black87),
                                );
                              }).toList();
                            },
                          ),
                        ),

                        lineBarsData: [
                          LineChartBarData(
                            spots: selectedTab == 0 ? heightData : diameterData,
                            isCurved: true,
                            curveSmoothness: 0.2,
                            barWidth: 3,
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.hunterGreen,
                                AppColors.gray600,
                              ],
                            ),
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.hunterGreen.withOpacity(0.3),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
        ),
      ],
    );
  }
}
