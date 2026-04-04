import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/tree/tree_details.dart';
import 'package:fyp_hbs/tree/create_tree.dart';
import 'package:fyp_hbs/tree/map.dart';
import 'package:fyp_hbs/widgets/persistent_appbar.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:fyp_hbs/authentication/reset_password.dart';
import 'package:fyp_hbs/authentication/login.dart';
import 'package:fyp_hbs/services/api/auth_service.dart';
import 'package:fyp_hbs/utils/connectivity_helper.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fyp_hbs/services/api/tree_api.dart';
import 'package:intl/intl.dart';

class TreePage extends StatefulWidget {
  const TreePage({super.key});

  @override
  State<TreePage> createState() => _TreePageState();
}

class _TreePageState extends State<TreePage> {
  List<Map<String, dynamic>> _trees = [];
  List<Map<String, dynamic>> _filtered = [];
  List<Map<String, dynamic>>? _allTreesCache;
  String? _lastSearchQuery;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Only trigger search on Enter/Submit. Keep listener to reset when cleared.
    _searchController.addListener(() {
      if (_searchController.text.trim().isEmpty) {
        _allTreesCache = null;
        _lastSearchQuery = null;
        _applySearch('');
      }
    });
    _scrollController.addListener(_onScroll);
    _fetchTrees(refresh: true);
  }

  Future<void> _fetchTrees({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _trees.clear();
    }

    if (_page == 1) setState(() => _isLoading = true);
    else setState(() => _isLoadingMore = true);

    try {
      final resp = await TreeApi.fetchTrees(page: _page);
      List<dynamic> raw = [];
      if (resp['data'] is Map) raw = resp['data']['data'] ?? [];
      else if (resp['data'] is List) raw = resp['data'];

      final cleaned = raw.map<Map<String, dynamic>>((e) {
        final t = (e is Map) ? Map<String, dynamic>.from(e) : {};
        return {
          'id': t['id'] ?? t['uuid'] ?? '',
          'uuid': t['uuid'] ?? t['id'] ?? '',
          'tree_tag': t['tree_tag'] ?? t['treeTag'] ?? 'Tree',
          'planted_at': t['planted_at'] ?? t['plantedAt'] ?? '',
          'species': t['species'] ?? {'name': 'Unknown'},
          'flowering_status': t['flowering_status'] ?? '-',
        };
      }).toList();

      // Append or set depending on page
      setState(() {
        if (_page == 1) {
          _trees = cleaned;
        } else {
          _trees.addAll(cleaned);
        }
        _filtered = List.from(_trees);
        // If returned fewer items than a full page, assume no more pages
        if (cleaned.isEmpty) _hasMore = false;
      });
      if (cleaned.isNotEmpty) _page += 1;
    } catch (e) {
      // on error, show empty list (only clear on first page)
      setState(() {
        if (_page == 1) {
          _trees = [];
          _filtered = [];
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = 200.0;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - threshold && !_isLoadingMore && !_isLoading && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    await _fetchTrees(refresh: false);
  }

  void _applySearch(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      _allTreesCache = null;
      _lastSearchQuery = null;
      setState(() => _filtered = List.from(_trees));
      return;
    }

    // For global search, fetch all trees (server-side pagination aggregated)
    // and cache the result to avoid repeated heavy requests.
    () async {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        List<Map<String, dynamic>> source;
        if (_allTreesCache != null && _lastSearchQuery == query) {
          source = _allTreesCache!;
        } else {
          final resp = await TreeApi.searchTrees(q: query, perPage: 200, page: 1);
          List<dynamic> raw = [];
          if (resp['data'] is Map) raw = resp['data']['data'] ?? [];
          else if (resp['data'] is List) raw = resp['data'];

          source = raw.map<Map<String, dynamic>>((e) {
            final t = (e is Map) ? Map<String, dynamic>.from(e) : {};
            return {
              'id': t['id'] ?? t['uuid'] ?? '',
              'uuid': t['uuid'] ?? t['id'] ?? '',
              'tree_tag': t['tree_tag'] ?? t['treeTag'] ?? 'Tree',
              'planted_at': t['planted_at'] ?? t['plantedAt'] ?? '',
              'species': t['species'] ?? {'name': 'Unknown'},
              'flowering_status': t['flowering_status'] ?? '-',
            };
          }).toList();

          _allTreesCache = source;
          _lastSearchQuery = query;
        }

        // Server-side search already returned matched items; use them directly.
        final results = source;
        // Debug: print counts to help diagnose missing items
        // ignore: avoid_print
        print('Tree search: query="$query" -> server returned ${source.length} items; client-filter skip');
        if (!mounted) return;
        setState(() => _filtered = results);
      } catch (e) {
        if (!mounted) return;
        setState(() => _filtered = []);
      } finally {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    }();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PersistentAppBar(
        title: 'Trees',
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _openSettings,
        ),
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MapPage()),
                      );
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.pakistanGreen,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.location_on, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (v) => _applySearch(v),
                      decoration: InputDecoration(
                        hintText: 'Search Tree',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: AppColors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: AppColors.gray400,
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: AppColors.hunterGreen,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateTreePage()),
                      );
                      if (result != null) _fetchTrees(refresh: true);
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.pakistanGreen,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.hunterGreen,
                      ),
                    )
                      : _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off, size: 48, color: AppColors.gray400),
                              const SizedBox(height: 12),
                              Text(
                                'No trees found',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.gray600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filtered.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index < _filtered.length) {
                              final tree = _filtered[index];
                              return _buildTreeCard(context, tree: tree);
                            }
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: AppColors.hunterGreen, strokeWidth: 2.5),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

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
              contentPadding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 0),
              leading: Icon(Icons.lock, color: AppColors.gray700),
              title: Text('Change Password', style: TextStyle(color: AppColors.gray700)),
              onTap: () async {
                final hasInternet = await ConnectivityHelper.hasInternetConnection();
                if (hasInternet) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetPasswordPage(fromSettings: true)));
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
              contentPadding: const EdgeInsets.only(left: 20, right: 20, top: 0, bottom: 20),
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                      ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Logout')),
                    ],
                  ),
                );

                if (shouldLogout == true) {
                  try {
                    final ok = await AuthService.logout();
                    if (ok) {
                      await Flushbar(
                        message: 'Logged out',
                        icon: const Icon(Icons.check_circle, color: Colors.white),
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

                    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
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

  Widget _buildTreeCard(BuildContext context, {required Map<String, dynamic> tree}) {
    final String tag = tree['tree_tag'] ?? 'Tree';
    final String rawDate = tree['planted_at']?.toString() ?? '';
    String displayDate = rawDate;
    if (rawDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDate);
        displayDate = DateFormat('yyyy-MM-dd').format(dt);
      } catch (_) {
        if (rawDate.contains('T')) displayDate = rawDate.split('T').first;
      }
    }
    final String uuid = tree['uuid']?.toString() ?? tree['id']?.toString() ?? '';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            SizedBox(width: 70, height: 70, child: QrImageView(data: uuid.isNotEmpty ? uuid : tag)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tag, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(tree['species']?['name']?.toString() ?? 'Unknown species', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(displayDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TreeDetailsPage(treeID: uuid)),
                );
                if (result != null) _fetchTrees(refresh: true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.mossGreen),
              child: const Text('View'),
            ),
          ],
        ),
      ),
    );
  }
}
