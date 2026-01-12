import 'package:flutter/material.dart';
import 'package:fyp_hbs/config.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/agrochemical_api.dart';
import 'package:fyp_hbs/widgets/persistent_appbar.dart';
import 'package:intl/intl.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:fyp_hbs/utils/connectivity_helper.dart';

class AgrochemicalListPage extends StatefulWidget {
  const AgrochemicalListPage({super.key});

  @override
  State<AgrochemicalListPage> createState() => _AgrochemicalListPageState();
}

class _AgrochemicalListPageState extends State<AgrochemicalListPage> {
  List<Map<String, dynamic>> _agrochemicals = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAvailableAgrochemicals();
  }

  Future<void> _loadAvailableAgrochemicals() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final agrochemicals =
          await AgrochemicalApi.getAvailableAgrochemicals();

      setState(() {
        _agrochemicals = agrochemicals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Available Agrochemicals',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.hunterGreen,
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error Loading Agrochemicals',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.gray600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadAvailableAgrochemicals,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _agrochemicals.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 48,
                            color: AppColors.gray500,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Agrochemicals Available',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No agrochemicals with stock available',
                            style: TextStyle(
                              color: AppColors.gray600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAvailableAgrochemicals,
                      color: AppColors.hunterGreen,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: _agrochemicals.length,
                        itemBuilder: (context, index) {
                          final agrochemical = _agrochemicals[index];
                          return _buildAgrochemicalCard(agrochemical);
                        },
                      ),
                    ),
    );
  }

  Widget _buildAgrochemicalCard(Map<String, dynamic> agrochemical) {
    final name = agrochemical['name'] ?? agrochemical['agrochemicalName'] ?? 'Unknown';
    final type = agrochemical['type'] ?? agrochemical['category'] ?? 'N/A';
    final description = agrochemical['description'] ?? 'No description available';
    
    // Try different field names for stock/quantity
    final stock = agrochemical['stock'] ?? 
                  agrochemical['quantity'] ?? 
                  agrochemical['remaining_stock'] ??
                  agrochemical['remaining'] ??
                  agrochemical['quantity_remaining'] ?? 
                  0;
    
    // Get thumbnail image
    final thumbRaw = (agrochemical['thumbnail'] ?? '').toString();
    final thumb = thumbRaw.isNotEmpty ? '${Config.supabaseBaseUrl}$thumbRaw' : '';
    final hasThumb = thumb.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 100,
                    height: 100,
                    color: AppColors.gray200,
                    child: hasThumb
                        ? Image.network(
                            thumb,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.agriculture,
                                  color: AppColors.gray500,
                                  size: 40,
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Icon(
                              Icons.agriculture,
                              color: AppColors.gray500,
                              size: 40,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        name.toString(),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.hunterGreen,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Type
                      Row(
                        children: [
                          Text(
                            'Type: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.gray600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              type.toString(),
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.gray700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Stock Available
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.dangerLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.inventory_2_rounded,
                                  size: 14,
                                  color: AppColors.danger,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$stock left',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.dangerActive,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Description
                      Text(
                        description.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.gray600,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Use Button (positioned at bottom right)
            Positioned(
              bottom: 0,
              right: 0,
              child: IconButton(
                onPressed: () async {
                  final hasInternet = await ConnectivityHelper.hasInternetConnection();
                  if (!hasInternet) {
                    if (context.mounted) {
                      await Flushbar(
                        message: 'Recording stock usage requires internet',
                        icon: const Icon(Icons.cloud_off, color: Colors.white),
                        backgroundColor: Colors.orange.shade700,
                        duration: const Duration(seconds: 2),
                        borderRadius: BorderRadius.circular(12),
                        margin: const EdgeInsets.all(12),
                        flushbarPosition: FlushbarPosition.TOP,
                      ).show(context);
                    }
                    return;
                  }
                  _showUseAgrochemicalDialog(agrochemical, stock);
                },
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.hunterGreen,
                iconSize: 28,
                tooltip: 'Use Agrochemical',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUseAgrochemicalDialog(Map<String, dynamic> agrochemical, int maxStock) {
    final agrochemicalUuid = agrochemical['uuid'] ?? agrochemical['id'] ?? '';
    final agrochemicalName = agrochemical['name'] ?? 'Unknown';
    
    int quantity = 1;
    DateTime selectedDate = DateTime.now();
    final TextEditingController dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(selectedDate),
    );

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Use $agrochemicalName',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Stock: $maxStock',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.gray600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Quantity Selector
                    Text(
                      'Quantity',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: quantity > 1
                              ? () {
                                  setDialogState(() {
                                    quantity--;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                          color: AppColors.hunterGreen,
                          iconSize: 32,
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.gray100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              quantity.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.hunterGreen,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: quantity < maxStock
                              ? () {
                                  setDialogState(() {
                                    quantity++;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                          color: AppColors.hunterGreen,
                          iconSize: 32,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Date Picker
                    Text(
                      'Date Used',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Select Date',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.hunterGreen,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                            dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.gray600),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await _confirmAndSubmitStockMovement(
                      agrochemicalUuid: agrochemicalUuid,
                      agrochemicalName: agrochemicalName,
                      quantity: quantity,
                      date: DateFormat('yyyy-MM-dd').format(selectedDate),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.hunterGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmAndSubmitStockMovement({
    required String agrochemicalUuid,
    required String agrochemicalName,
    required int quantity,
    required String date,
  }) async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Usage'),
          content: Text(
            'Are you sure you want to record the usage of $quantity unit(s) of $agrochemicalName on $date?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.gray600),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.hunterGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    // Show loading
    Flushbar(
      message: 'Recording usage...',
      icon: const Icon(Icons.sync, color: Colors.white),
      backgroundColor: AppColors.hunterGreen,
      duration: const Duration(seconds: 2),
      borderRadius: BorderRadius.circular(8),
      margin: const EdgeInsets.all(12),
    ).show(context);

    try {
      await AgrochemicalApi.createStockMovement(
        agrochemicalUuid: agrochemicalUuid,
        quantity: quantity,
        date: date,
      );

      // Reload the list to update stock
      await _loadAvailableAgrochemicals();

      Flushbar(
        message: 'Usage recorded successfully',
        icon: const Icon(Icons.check_circle, color: Colors.white),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
        borderRadius: BorderRadius.circular(8),
        margin: const EdgeInsets.all(12),
      ).show(context);
    } catch (e) {
      Flushbar(
        message: 'Failed to record usage: ${e.toString().replaceFirst('Exception: ', '')}',
        icon: const Icon(Icons.error, color: Colors.white),
        backgroundColor: AppColors.danger,
        duration: const Duration(seconds: 4),
        borderRadius: BorderRadius.circular(8),
        margin: const EdgeInsets.all(12),
      ).show(context);
    }
  }
}
