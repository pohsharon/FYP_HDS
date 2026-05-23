import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/widgets/persistent_appbar.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:fyp_hbs/authentication/reset_password.dart';
import 'package:fyp_hbs/authentication/login.dart';
import 'package:fyp_hbs/services/api/auth_service.dart';
import 'package:fyp_hbs/utils/connectivity_helper.dart';
import '../services/api/harvest_api.dart';
import 'package:fyp_hbs/harvest/widgets/harvest_info_modal.dart';
import 'package:fyp_hbs/tree/tree_details.dart';
import 'package:fyp_hbs/harvest/create_harvest_grade.dart';

class HarvestPage extends StatefulWidget {
  const HarvestPage({super.key});

  @override
  State<HarvestPage> createState() => _HarvestPageState();
}

class _HarvestPageState extends State<HarvestPage> {
  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 10,
                bottom: 0,
              ),
              leading: Icon(Icons.lock, color: AppColors.gray700),
              title: Text(
                'Change Password',
                style: TextStyle(color: AppColors.gray700),
              ),
              onTap: () async {
                final hasInternet =
                    await ConnectivityHelper.hasInternetConnection();
                if (hasInternet) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => const ResetPasswordPage(fromSettings: true),
                    ),
                  );
                } else {
                  await Flushbar(
                    message: 'Changing password requires internet connection',
                    icon: const Icon(Icons.cloud_off, color: Colors.white),
                    backgroundColor: Colors.orange.shade700,
                    duration: const Duration(seconds: 2),
                    borderRadius: BorderRadius.circular(12),
                    margin: const EdgeInsets.all(12),
                    flushbarPosition: FlushbarPosition.TOP,
                  ).show(context);
                }
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 0,
                bottom: 20,
              ),
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Confirm Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                );

                if (shouldLogout == true) {
                  try {
                    final ok = await AuthService.logout();

                    if (ok) {
                      await Flushbar(
                        message: 'Logged out',
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
                    } else {
                      await Flushbar(
                        message: 'Logging out',
                        icon: const Icon(Icons.info, color: Colors.white),
                        backgroundColor: Colors.orange.shade700,
                        duration: const Duration(seconds: 2),
                        borderRadius: BorderRadius.circular(12),
                        margin: const EdgeInsets.all(12),
                        flushbarPosition: FlushbarPosition.TOP,
                      ).show(context);
                    }

                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                    );
                  } catch (e) {
                    await Flushbar(
                      message: 'Logout failed: $e',
                      icon: const Icon(Icons.error, color: Colors.white),
                      backgroundColor: Colors.red.shade700,
                      duration: const Duration(seconds: 3),
                      borderRadius: BorderRadius.circular(12),
                      margin: const EdgeInsets.all(12),
                      flushbarPosition: FlushbarPosition.TOP,
                    ).show(context);
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Map<String, dynamic>? _summary;
  bool _loadingSummary = true;
  String _period = 'day'; // 'day' | 'week' | 'season'
  DateTime _selectedDay = DateTime.now();
  DateTime _selectedWeekDate = DateTime.now();
  List<Map<String, dynamic>> _details = [];
  bool _loadingDetails = true;

  String _formatDate(DateTime d) => d.toIso8601String().split('T').first;

  @override
  void initState() {
    super.initState();
    _loadSummary(_period);
  }

  Future<void> _loadSummary(String period) async {
    setState(() {
      _loadingSummary = true;
      _period = period;
    });

    try {
      Map<String, dynamic> data;
      if (period == 'day') {
        // Fetch range for the selected day so user can pick arbitrary dates
        final d = _formatDate(_selectedDay);
        data = await HarvestApi.fetchDaySummary(date: d);
      } else if (period == 'week') {
        // Calculate week range based on the selected week date
        final wd = _selectedWeekDate.weekday; // 1 = Monday
        final monday = _selectedWeekDate.subtract(Duration(days: wd - 1));
        final sunday = monday.add(const Duration(days: 6));
        data = await HarvestApi.fetchWeekSummary(from: _formatDate(monday), to: _formatDate(sunday));
      } else {
        data = await HarvestApi.fetchSeasonSummary();
      }

      setState(() {
        _summary = data;
        _loadingDetails = true;
        _details = [];
      });
    
      // determine range to fetch details for from state
      String from = '';
      String to = '';
      final now = DateTime.now();

      if (period == 'day') {
        // selected day
        from = _formatDate(_selectedDay);
        to = from;
      } else if (period == 'week') {
        // week: Monday -> Sunday based on the selected week date
        final wd = _selectedWeekDate.weekday; // 1 = Monday
        final monday = _selectedWeekDate.subtract(Duration(days: wd - 1));
        final sunday = monday.add(const Duration(days: 6));
        from = _formatDate(monday);
        to = _formatDate(sunday);
      } else {
        // season: from first harvest day (prefer server-provided), to today
        final serverFrom = data['from']?.toString();
        if (serverFrom != null && serverFrom.isNotEmpty) {
          from = serverFrom.length >= 10 ? serverFrom.substring(0, 10) : serverFrom;
        } else {
          // fallback: start of current year
          from = _formatDate(DateTime(now.year, 1, 1));
        }
        to = _formatDate(now);
      }

      if (from.isNotEmpty && to.isNotEmpty) {
        try {
          final range = await HarvestApi.fetchRangeSummary(from: from, to: to);
          final rawDetails = range['details'];

          if (rawDetails is List) {
            final parsed =
                rawDetails.map<Map<String, dynamic>>((e) {
                  if (e is Map) return Map<String, dynamic>.from(e);
                  return <String, dynamic>{};
                }).toList();

            if (mounted) setState(() => _details = parsed);
          }
        } catch (e) {
          if (mounted) setState(() => _details = []);
        } finally {
          if (mounted) setState(() => _loadingDetails = false);
        }
      } else {
        if (mounted) setState(() => _loadingDetails = false);
      }
    } catch (e) {
      setState(() => _summary = null);
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PersistentAppBar(
        title: 'Harvest',
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _openSettings,
        ),
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildPeriodSelector(),
              if (_period == 'day')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Date: ${_formatDate(_selectedDay)}',
                          style: TextStyle(color: AppColors.gray800, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today_outlined),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDay,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null && picked != _selectedDay) {
                            setState(() {
                              _selectedDay = picked;
                              _loadingSummary = true;
                            });
                            await _loadSummary('day');
                          }
                        },
                      ),
                    ],
                  ),
                ),
              if (_period == 'week')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Week of: ${_formatDate(_selectedWeekDate.subtract(Duration(days: _selectedWeekDate.weekday - 1)))}',
                          style: TextStyle(color: AppColors.gray800, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today_outlined),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedWeekDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null && picked != _selectedWeekDate) {
                            setState(() {
                              _selectedWeekDate = picked;
                              _loadingSummary = true;
                            });
                            await _loadSummary('week');
                          }
                        },
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              _buildSummaryCard(),
              const SizedBox(height: 18),
              const SizedBox(height: 6),
              Expanded(
                child:
                    _loadingDetails
                        ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.hunterGreen,
                          ),
                        )
                        : _details.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'No records',
                                      style: TextStyle(color: AppColors.gray700),
                                    ),
                                  
                                  ],
                                ),
                              )
                        : ListView.separated(
                          itemCount: _details.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = _details[index];
                            final tag =
                              item['tree_tag']?.toString() ??
                              item['tree_uuid']?.toString() ??
                              'Unknown';
                            final treeUuid = item['tree_uuid']?.toString() ?? '';
                            final spoiltWeight =
                              item['spoilt_weight']?.toString() ?? '0';
                            final notSpoiltWeight =
                              item['not_spoilt_weight']?.toString() ?? '0';
                            // Consider this record spoilt when spoilt weight > 0
                            final spoilW = double.tryParse(spoiltWeight) ?? 0.0;
                            final notSpoilW = double.tryParse(notSpoiltWeight) ?? 0.0;
                            final spoiltFruits =
                                int.tryParse(
                                  item['spoilt_fruits']?.toString() ?? '0',
                                ) ??
                                0;
                            final notSpoiltFruits =
                                int.tryParse(
                                  item['not_spoilt_fruits']?.toString() ?? '0',
                                ) ??
                                0;

                            // Build separate cards when both spoilt and not-spoilt weights exist
                            final List<Widget> cards = [];

                            if (notSpoilW > 0 || (spoilW == 0 && notSpoilW == 0)) {
                              // Not-spoilt card (or fallback when both zero)
                              cards.add(Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.hunterGreen,
                                    child: Text(
                                      tag.split('-').last,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    tag,
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  onTap: () async {
                                    if (treeUuid.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => TreeDetailsPage(treeID: treeUuid),
                                        ),
                                      );
                                    } else {
                                      await Flushbar(
                                        message: 'Tree details unavailable',
                                        icon: const Icon(Icons.info, color: Colors.white),
                                        backgroundColor: Colors.orange.shade700,
                                        duration: const Duration(seconds: 2),
                                        borderRadius: BorderRadius.circular(12),
                                        margin: const EdgeInsets.all(12),
                                        flushbarPosition: FlushbarPosition.TOP,
                                      ).show(context);
                                    }
                                  },
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                       '${notSpoiltFruits} fruits',
                                        style: TextStyle(
                                          color: AppColors.hunterGreen,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      // const SizedBox(height: 4),
                                      // Text(
                                      //   '${notSpoiltFruits} fruits',
                                      //   style: TextStyle(
                                      //     color: AppColors.gray600,
                                      //   ),
                                      // ),
                                    ],
                                  ),
                                ),
                              ));
                            }

                            if (spoilW > 0) {
                              // Spoilt card
                              cards.add(Card(
                                color: AppColors.dangerLight,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.hunterGreen,
                                    child: Text(
                                      tag.split('-').last,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    '$tag (Spoilt)',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  onTap: () async {
                                    if (treeUuid.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => TreeDetailsPage(treeID: treeUuid),
                                        ),
                                      );
                                    } else {
                                      await Flushbar(
                                        message: 'Tree details unavailable',
                                        icon: const Icon(Icons.info, color: Colors.white),
                                        backgroundColor: Colors.orange.shade700,
                                        duration: const Duration(seconds: 2),
                                        borderRadius: BorderRadius.circular(12),
                                        margin: const EdgeInsets.all(12),
                                        flushbarPosition: FlushbarPosition.TOP,
                                      ).show(context);
                                    }
                                  },
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // Text(
                                      //   '${spoilW.toStringAsFixed(2)} kg',
                                      //   style: TextStyle(
                                      //     color: Colors.red,
                                      //     fontWeight: FontWeight.bold,
                                      //   ),
                                      // ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${spoiltFruits} fruits',
                                        style: TextStyle(
                                          color: AppColors.gray600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ));
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: cards,
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    Widget btn(String id, String label) {
      final selected = _period == id;
      return Expanded(
        child: ElevatedButton(
          onPressed: () => _loadSummary(id),
          style: ElevatedButton.styleFrom(
            backgroundColor: selected ? AppColors.hunterGreen : AppColors.white,
            foregroundColor: selected ? Colors.white : AppColors.gray700,
            elevation: selected ? 2 : 0,
            side: BorderSide(color: AppColors.gray300),
          ),
          child: Text(label),
        ),
      );
    }

    return Row(
      children: [
        btn('day', 'Day'),
        const SizedBox(width: 8),
        btn('week', 'Week'),
        const SizedBox(width: 8),
        btn('season', 'Season'),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final data = _summary ?? {};
    // Normalize totals map from possible response shapes: {totals: {...}} or {data: {totals: {...}}}
    Map<String, dynamic> totals = {};
    try {
      if (data['totals'] is Map) totals = Map<String, dynamic>.from(data['totals']);
      else if (data['data'] is Map && data['data']['totals'] is Map) totals = Map<String, dynamic>.from(data['data']['totals']);
    } catch (_) {
      totals = {};
    }

    final spoiltFruits = (totals['spoilt_fruits'] ?? 0).toString();
    final notSpoiltFruits = (totals['not_spoilt_fruits'] ?? 0).toString();

    String subtitle = '';
    if (data.containsKey('date')) {
      subtitle = data['date'].toString();
    } else if (data.containsKey('from') || data.containsKey('to')) {
      final from = data['from']?.toString() ?? '';
      final to = data['to']?.toString() ?? '';
      subtitle = (from.isNotEmpty || to.isNotEmpty) ? '$from — $to' : '';
    }

    final range = _currentPeriodRange();

    return HarvestSummaryCarouselCard(
      period: _period,
      subtitle: subtitle,
      rangeStart: range['start']!,
      rangeEnd: range['end'],
      loadingSummary: _loadingSummary,
      spoiltFruits: spoiltFruits,
      notSpoiltFruits: notSpoiltFruits,
      onCreateHarvestGrade: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateHarvestGradePage()),
        );
        _loadSummary(_period);
      },
      gradeTotalsFuture: _fetchAndAggregateGrades(
        start: range['start']!,
        end: range['end'],
      ),
    );
  }

  Map<String, String> _currentPeriodRange() {
    if (_period == 'day') {
      final date = _formatDate(_selectedDay);
      return {'start': date, 'end': date};
    }

    if (_period == 'week') {
      final wd = _selectedWeekDate.weekday; // 1 = Monday
      final monday = _selectedWeekDate.subtract(Duration(days: wd - 1));
      final sunday = monday.add(const Duration(days: 6));
      return {
        'start': _formatDate(monday),
        'end': _formatDate(sunday),
      };
    }

    final now = DateTime.now();
    final serverFrom = _summary?['from']?.toString();
    final start = (serverFrom != null && serverFrom.isNotEmpty)
        ? (serverFrom.length >= 10 ? serverFrom.substring(0, 10) : serverFrom)
        : _formatDate(DateTime(now.year, 1, 1));

    return {
      'start': start,
      'end': _formatDate(now),
    };
  }

  Future<Map<String, double>> _fetchAndAggregateGrades({
    required String start,
    String? end,
  }) async {
    final Map<String, double> totals = {};
    try {
      final resp = await HarvestApi.fetchHarvestGradesByDate(
        start: start,
        end: end,
      );
      final list = resp['data'] as List? ?? [];
      for (final item in list) {
        if (item is Map) {
          final grade = (item['grade'] ?? 'Unspecified').toString();
          final wRaw = item['weight'];
          double w = 0.0;
          if (wRaw is num) w = wRaw.toDouble();
          else if (wRaw is String) w = double.tryParse(wRaw) ?? 0.0;
          totals[grade] = (totals[grade] ?? 0.0) + w;
        }
      }
    } catch (_) {
      // keep empty totals when the range fetch fails
    }
    return totals;
  }
}

class HarvestSummaryCarouselCard extends StatefulWidget {
  const HarvestSummaryCarouselCard({
    super.key,
    required this.period,
    required this.subtitle,
    required this.rangeStart,
    required this.rangeEnd,
    required this.loadingSummary,
    required this.notSpoiltFruits,
    required this.spoiltFruits,
    required this.onCreateHarvestGrade,
    required this.gradeTotalsFuture,
  });

  final String period;
  final String subtitle;
  final String rangeStart;
  final String? rangeEnd;
  final bool loadingSummary;
  final String notSpoiltFruits;
  final String spoiltFruits;
  final VoidCallback onCreateHarvestGrade;
  final Future<Map<String, double>> gradeTotalsFuture;

  @override
  State<HarvestSummaryCarouselCard> createState() => _HarvestSummaryCarouselCardState();
}

class _HarvestSummaryCarouselCardState extends State<HarvestSummaryCarouselCard> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.96);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [
                _buildSummaryPage(),
                _buildGradeTotalsPage(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDot(0),
              const SizedBox(width: 6),
              _buildDot(1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    final selected = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: selected ? 18 : 7,
      height: 7,
      decoration: BoxDecoration(
        color: selected ? AppColors.hunterGreen : AppColors.gray300,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _panel({required Widget child, required VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.white, AppColors.background],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryPage() {
    return _panel(
      onTap: widget.onCreateHarvestGrade,
      child: widget.loadingSummary
          ? Center(
              child: CircularProgressIndicator(color: AppColors.hunterGreen),
            )
          : Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.hunterGreen, AppColors.mossGreen],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.agriculture, color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${widget.period[0].toUpperCase()}${widget.period.substring(1)} Harvest',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gray800,
                        ),
                      ),
                      if (widget.subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0, bottom: 6.0),
                          child: Text(
                            widget.subtitle,
                            style: TextStyle(color: AppColors.gray600),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: _metricRow(
                              icon: Icons.eco_rounded,
                              iconColor: AppColors.hunterGreen,
                              label: 'Not spoilt',
                              value: '${widget.notSpoiltFruits} fruits',
                              valueColor: AppColors.hunterGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _metricRow(
                              icon: Icons.warning_amber_rounded,
                              iconColor: Colors.red,
                              label: 'Spoilt',
                              value: '${widget.spoiltFruits} fruits',
                              valueColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Swipe for grade totals',
                        style: TextStyle(
                          color: AppColors.gray500,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _metricRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(color: AppColors.gray600, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGradeTotalsPage() {
    return _panel(
      onTap: () {
        showHarvestInfoModal(
          context,
          start: widget.rangeStart,
          end: widget.rangeEnd,
          title: '${widget.period[0].toUpperCase()}${widget.period.substring(1)} Harvest Info',
        );
      },
      child: FutureBuilder<Map<String, double>>(
        future: widget.gradeTotalsFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.hunterGreen),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Failed to load grade totals',
                style: TextStyle(color: AppColors.gray700),
              ),
            );
          }

          final entries = (snap.data ?? {}).entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final totalWeight = entries.fold<double>(
            0.0,
            (sum, entry) => sum + entry.value,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${widget.period[0].toUpperCase()}${widget.period.substring(1)} Total Weight',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gray800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${totalWeight.toStringAsFixed(2)} kg',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.hunterGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to open harvest info',
                style: TextStyle(
                  color: AppColors.gray500,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
