import 'package:flutter/material.dart';
import 'package:fyp_hbs/config.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/agrochemical_api.dart';
import 'package:fyp_hbs/tree/tab/agrochemical/create_agrochemical.dart';
import 'package:fyp_hbs/utils/connectivity_helper.dart';
import 'package:fyp_hbs/services/local database/agro_db.dart';
import 'package:fyp_hbs/models/agrochemical_model.dart';
import 'package:intl/intl.dart';

class AgrochemicalTabPage extends StatefulWidget {
  final String treeUuid;
  final String treeTag;
  const AgrochemicalTabPage({super.key, required this.treeUuid, required this.treeTag});

  @override
  State<AgrochemicalTabPage> createState() => _AgrochemicalTabPageState();
}

class _AgrochemicalTabPageState extends State<AgrochemicalTabPage> {
  String searchQuery = '';

  Future<List<Map<String, dynamic>>> fetchAgrochemical() async {
    try {
      final online = await ConnectivityHelper.hasInternetConnection();
      if (online) {
        final response = await AgrochemicalApi.fetchAgrochemicals(
          treeUuid: widget.treeUuid,
        );
        return response;
      }
    } catch (e) {
      print('⚠️ Agrochemical fetch remote failed or no connectivity: $e');
    }

    try {
      final local = await AgroDB().fetchByTreeUuid(widget.treeUuid);
      final mapped = local.map((AgrochemicalModel m) {
        return {
          'agrochemical': {
            'name': m.agrochemicalName ?? 'Unknown Agrochemical',
            'thumbnail': null,
          },
          'applied_at': m.applied_at ?? '',
          'description': m.description ?? '',
          'tree_uuid': m.tree_uuid ?? widget.treeUuid,
          'synced': m.synced,
          'pending_update': m.pendingUpdate,
          'pending_delete': m.pendingDelete,
        };
      }).toList();
      return mapped;
    } catch (e) {
      print('⚠️ Failed to read local agrochemical DB: $e');
      return <Map<String, dynamic>>[];
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'No date';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _getTimeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()}y ago';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()}mo ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else {
        return 'Today';
      }
    } catch (e) {
      return '';
    }
  }

  Color _getAgrochemicalColor(int index) {
    final colors = [
      AppColors.hunterGreen,
      AppColors.mossGreen,
      Colors.teal,
      Colors.green.shade700,
      Colors.lightGreen.shade700,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 🔍 Search + Add Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search Agrochemical',
                    hintStyle: TextStyle(
                      color: AppColors.gray600,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () => setState(() => searchQuery = ''),
                            child: const Icon(Icons.clear),
                          )
                        : const Icon(Icons.filter_alt_outlined),
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
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateAgrochemicalPage(
                        treeUuid: widget.treeUuid,
                        treeTag: widget.treeTag,
                        agrochemicalRecord: null,
                      ),
                    ),
                  );
                  if (result == true) setState(() {});
                },
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                label: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.hunterGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),

        // 📋 Agrochemical Records
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: fetchAgrochemical(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: AppColors.danger),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading records',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        style: TextStyle(fontSize: 12, color: AppColors.gray600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              
              final items = snapshot.data ?? [];
              final filtered = items.where((item) {
                final name = item['agrochemical']?['name']?.toString().toLowerCase() ?? '';
                return name.contains(searchQuery.toLowerCase());
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.gray200,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.science_outlined,
                          size: 64,
                          color: AppColors.gray600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        searchQuery.isEmpty 
                            ? 'No agrochemical records yet' 
                            : 'No results found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        searchQuery.isEmpty
                            ? 'Tap the Add button to create your first record'
                            : 'Try a different search term',
                        style: TextStyle(fontSize: 14, color: AppColors.gray600),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final agro = item['agrochemical'] ?? {};
                  final cardColor = _getAgrochemicalColor(index);
                  final thumbRaw = (agro['thumbnail'] ?? item['thumbnail'] ?? '').toString();
                  final thumb = thumbRaw.isNotEmpty ? '${Config.supabaseBaseUrl}$thumbRaw' : '';
                  final hasThumb = thumb.isNotEmpty;
                  final appliedAt = item['applied_at']?.toString() ?? '';
                  final description = item['description']?.toString() ?? '';

                  return GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateAgrochemicalPage(
                            treeUuid: widget.treeUuid,
                            treeTag: widget.treeTag,
                            agrochemicalRecord: item,
                          ),
                        ),
                      );

                      if (result == true) {
                        setState(() {});
                      }
                    },
                    child: Card(
                      elevation: 2,
                      shadowColor: Colors.black.withOpacity(0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: AppColors.gray200,
                          width: 1,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: AppColors.white,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Thumbnail or fallback icon
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: hasThumb ? Colors.transparent : cardColor,
                                  gradient: hasThumb
                                      ? null
                                      : LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [cardColor, cardColor.withOpacity(0.7)],
                                        ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: cardColor.withOpacity(0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: hasThumb
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          thumb,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Center(
                                            child: Icon(Icons.science, color: Colors.white, size: 28),
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.science, color: Colors.white, size: 28),
                              ),

                              const SizedBox(width: 16),

                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Agrochemical Name
                                    Text(
                                      agro['name'] ?? 'Unknown Agrochemical',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                        color: AppColors.gray900,
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    // Applied Date Row
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: AppColors.gray600,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatDate(appliedAt),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.gray700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (appliedAt.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: cardColor.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: cardColor.withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              _getTimeAgo(appliedAt),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: cardColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),

                                    // Description (if available)
                                    if (description.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.gray200.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.notes,
                                              size: 14,
                                              color: AppColors.gray600,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                description,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.gray700,
                                                  height: 1.3,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Chevron Icon
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.gray200.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.chevron_right,
                                  color: AppColors.gray600,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}