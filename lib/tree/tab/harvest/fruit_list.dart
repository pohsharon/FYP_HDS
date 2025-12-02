import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/tree_api.dart';
import 'package:fyp_hbs/services/local database/fruit_db.dart';
import 'package:qr_flutter/qr_flutter.dart';

class FruitListPage extends StatefulWidget {
  final String treeUuid; // <-- pass in the tree UUID
  final String? harvestUuid; // optional: show a single harvest's fruits

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

      // If a specific harvestUuid was requested, try to find it in remote events
      if (widget.harvestUuid != null && widget.harvestUuid!.isNotEmpty) {
        final String target = widget.harvestUuid!;
        // first try remote payload
        Map<String, dynamic>? matched;
        for (final ev in events) {
          final evUuid = (ev['uuid'] ?? ev['id'] ?? ev['harvest_uuid'])?.toString();
          if (evUuid == target) {
            matched = Map<String, dynamic>.from(ev);
            break;
          }
          // if fruits present, check their harvest_uuid / tree_uuid
          if (ev['fruits'] is List) {
            final list = List.from(ev['fruits']);
            if (list.any((f) => (f['harvest_uuid'] ?? '') == target || (f['tree_uuid'] ?? '') == widget.treeUuid)) {
              matched = Map<String, dynamic>.from(ev);
              break;
            }
          }
        }

        if (matched != null) {
          // restrict fruits to this tree if possible
          List<Map<String, dynamic>> fruits = [];
          if (matched['fruits'] is List) {
            for (final f in matched['fruits']) {
              if ((f['tree_uuid'] ?? '') == widget.treeUuid || (f['harvest_uuid'] ?? '') == target) {
                fruits.add(Map<String, dynamic>.from(f));
              }
            }
          }

          // if remote didn't contain fruits for this tree, fall back to local DB
          if (fruits.isEmpty) {
            final local = await FruitDB().getAllFruits();
            final localMatches = local.where((f) => (f.harvest_uuid ?? '') == target && (f.tree_uuid ?? '') == widget.treeUuid).toList();
            for (final lm in localMatches) fruits.add(lm.toMap());
          }

          final matchedNonNull = matched;
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
          return;
        }

        // if not found remotely, try local DB for this harvest
        final local = await FruitDB().getAllFruits();
        final localMatches = local.where((f) => (f.harvest_uuid ?? '') == widget.harvestUuid && (f.tree_uuid ?? '') == widget.treeUuid).toList();
        if (localMatches.isNotEmpty) {
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

      // default: show all remote events (existing behavior)
      setState(() {
        _harvestEvents = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading harvest events: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Harvest Events",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.pakistanGreen,
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _harvestEvents.isEmpty
                ? const Center(child: Text("No harvest events found"))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _harvestEvents.length,
                    itemBuilder: (context, index) {
                      final event = _harvestEvents[index];
                      final fruits =
                          List<Map<String, dynamic>>.from(event['fruits']);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event['event_name'] ?? 'Unnamed Event',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: AppColors.hunterGreen,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Start: ${event['start_date'] ?? '-'} | End: ${event['end_date'] ?? 'Ongoing'}",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                              const Divider(height: 20, thickness: 1),

                              // Fruits under this harvest
                              ...fruits.map((fruit) => _buildFruitCard(fruit)),
                            ],
                          ),
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
    final String uuid = fruit['uuid'];

    return Card(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.gray400),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      child: ListTile(
        leading: SizedBox(
          width: 50,
          height: 50,
          child: QrImageView(data: uuid, version: QrVersions.auto),
        ),
        title: Text(
          tag,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("$weight kg | Grade $grade"),
        onTap: () => _showFruitDetailsDialog(context, fruit),
        trailing: OutlinedButton(
          onPressed: () => _showFruitDetailsDialog(context, fruit),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.hunterGreen,
            side: const BorderSide(color: AppColors.hunterGreen),
            minimumSize: const Size(60, 30),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: const Text("View"),
        ),
      ),
    );
  }

  void _showFruitDetailsDialog(
    BuildContext context,
    Map<String, dynamic> fruit,
  ) {
    final String uuid = fruit['uuid'] ?? '';
    final String tag = fruit['fruit_tag'] ?? 'Unknown';
    final String date = fruit['harvested_at'] ?? '';
    final String weight = fruit['weight']?.toString() ?? '';
    final String grade = fruit['grade'] ?? '';
    final String? transactionId = fruit['transaction_uuid'];

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                QrImageView(
                  data: uuid,
                  version: QrVersions.auto,
                  size: 150,
                  gapless: true,
                ),
                const SizedBox(height: 4),
                Text(
                  uuid,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  tag,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: AppColors.hunterGreen,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDetailRow("Date", date),
                _buildDetailRow("Weight", "$weight kg"),
                _buildDetailRow("Grade", grade),
                const SizedBox(height: 16),
                if (transactionId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningActive,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Sold",
                      style: TextStyle(
                        color: AppColors.hunterGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.hunterGreen,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.mossGreen,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
