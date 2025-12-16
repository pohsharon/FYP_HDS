import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/tree_growth_api.dart';
import 'package:fyp_hbs/models/tree_growth_model.dart';
import 'package:fyp_hbs/services/local database/growth_db.dart';
import 'package:another_flushbar/flushbar.dart';

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
      // Try remote API first
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

  @override
  Widget build(BuildContext context) {
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
                                    if (height.isNotEmpty &&
                                        diameter.isNotEmpty) {
                                      try {
                                        // Try remote create first
                                        await TreeGrowthApi.addGrowthLog(
                                          treeUuid: widget.treeUuid,
                                          height: double.parse(height),
                                          diameter: double.parse(diameter),
                                        );

                                        Navigator.pop(context, true);
                                        await _fetchGrowthLogs();
                                        if (mounted) setState(() {});
                                      } catch (e) {
                                        // Remote failed: save locally so user action isn't lost
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
                                          Navigator.pop(context, true);
                                          await _fetchGrowthLogs();
                                          if (mounted) setState(() {});
                                        } catch (localErr) {
                                          print('Failed to save growth locally: $localErr');
                                          await Flushbar(
                                            message: 'Failed to save growth log: $localErr',
                                            backgroundColor: Colors.red.shade700,
                                            duration: const Duration(seconds: 3),
                                            margin: const EdgeInsets.all(12),
                                            borderRadius: BorderRadius.circular(8),
                                          ).show(context);
                                        }
                                      }
                                    } else {
                                      await Flushbar(
                                        message: 'Please enter height and diameter',
                                        backgroundColor: Colors.orange.shade700,
                                        duration: const Duration(seconds: 2),
                                        margin: const EdgeInsets.all(12),
                                        borderRadius: BorderRadius.circular(8),
                                      ).show(context);
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
                        maxX: xLabels.isNotEmpty
                            ? (xLabels.length - 1).toDouble()
                            : 0,
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),

                          // Left Y-axis
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                            ),
                          ),

                          // Bottom X-axis with month/year labels
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < xLabels.length) {
                                  return Text(
                                    xLabels[index],
                                    style: const TextStyle(fontSize: 10),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
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

                        lineBarsData: [
                          LineChartBarData(
                            spots: selectedTab == 0 ? heightData : diameterData,
                            isCurved: false,
                            color: AppColors.hunterGreen,
                            barWidth: 3,
                            dotData: FlDotData(show: true),
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
