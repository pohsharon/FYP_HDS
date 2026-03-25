import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/widgets/persistent_appbar.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:fyp_hbs/authentication/reset_password.dart';
import 'package:fyp_hbs/authentication/login.dart';
import 'package:fyp_hbs/services/api/auth_service.dart';
import 'package:fyp_hbs/utils/connectivity_helper.dart';
import '../services/api/harvest_api.dart';

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
  List<Map<String, dynamic>> _details = [];
  bool _loadingDetails = true;
  String? _lastRangeRaw;

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
        data = await HarvestApi.fetchDaySummary();
      } else if (period == 'week') {
        data = await HarvestApi.fetchWeekSummary();
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
        // today
        from = _formatDate(now);
        to = from;
      } else if (period == 'week') {
        // week: Monday -> Sunday
        final wd = now.weekday; // 1 = Monday
        final monday = now.subtract(Duration(days: wd - 1));
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
          final rawBody = range['_raw_body']?.toString();
          if (mounted) setState(() => _lastRangeRaw = rawBody);

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
          if (mounted) setState(() => _lastRangeRaw = e.toString());
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
                            final spoiltWeight =
                                item['spoilt_weight']?.toString() ?? '0';
                            final notSpoiltWeight =
                                item['not_spoilt_weight']?.toString() ?? '0';
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
                            final totalFruits = spoiltFruits + notSpoiltFruits;
                            final weight =
                                double.tryParse(notSpoiltWeight) ?? 0.0;

                            return Card(
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
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${weight.toStringAsFixed(2)} kg',
                                      style: TextStyle(
                                        color: AppColors.hunterGreen,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$totalFruits fruits',
                                      style: TextStyle(
                                        color: AppColors.gray600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
    final totals = data['totals'] ?? {};
    final spoiltWeight = (totals['spoilt_weight'] ?? '0').toString();
    final notSpoiltWeight = (totals['not_spoilt_weight'] ?? '0').toString();
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

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
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
        child:
            _loadingSummary
                ? SizedBox(
                  height: 90,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.hunterGreen,
                    ),
                  ),
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
                        child: Icon(
                          Icons.agriculture,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_period[0].toUpperCase()}${_period.substring(1)} Harvest',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gray800,
                            ),
                          ),
                          if (subtitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 6.0,
                                bottom: 6.0,
                              ),
                              child: Text(
                                subtitle,
                                style: TextStyle(color: AppColors.gray600),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Collected',
                                      style: TextStyle(
                                        color: AppColors.gray600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '$notSpoiltWeight kg',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.hunterGreen,
                                      ),
                                    ),
                                    Text(
                                      '$notSpoiltFruits fruits',
                                      style: TextStyle(
                                        color: AppColors.gray600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Spoilt',
                                      style: TextStyle(
                                        color: AppColors.gray600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '$spoiltWeight kg',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                    Text(
                                      '$spoiltFruits fruits',
                                      style: TextStyle(
                                        color: AppColors.gray600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
