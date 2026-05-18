import 'package:flutter/material.dart';

import 'package:fyp_hbs/services/api/harvest_api.dart';
import 'package:fyp_hbs/theme/app_colors.dart';

class _HarvestDetailsSummary {
  final String date;
  final int count;
  final double totalWeight;
  final Map<String, double> gradeWeights;
  final Map<String, double> speciesWeights;

  const _HarvestDetailsSummary({
    required this.date,
    required this.count,
    required this.totalWeight,
    required this.gradeWeights,
    required this.speciesWeights,
  });
}

Future<void> showHarvestInfoModal(BuildContext context, {String? date}) async {
  final future = _loadHarvestDetails(date: date);

  if (!context.mounted) return;
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: FutureBuilder<_HarvestDetailsSummary>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Harvest info',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text('Failed to load harvest details: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              );
            }

            final summary = snapshot.data!;
            final gradeOrder = ['A', 'AB', 'B', 'C', 'CC', 'Z', 'Unspecified'];
            final speciesEntries = summary.speciesWeights.entries.toList()
              ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Harvest info',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Text('Date: ${summary.date}'),
                    const SizedBox(height: 8),
                    Text('Records: ${summary.count}'),
                    const SizedBox(height: 8),
                    Text(
                      'Total weight: ${summary.totalWeight.toStringAsFixed(2)} kg',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Weight by grade',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    ...gradeOrder.map(
                      (grade) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 88,
                              child: Text(
                                grade,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Expanded(
                              child: LinearProgressIndicator(
                                minHeight: 10,
                                value: summary.totalWeight > 0
                                    ? (summary.gradeWeights[grade] ?? 0) / summary.totalWeight
                                    : 0,
                                backgroundColor: Colors.grey.shade200,
                                color: AppColors.hunterGreen,
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 90,
                              child: Text(
                                '${(summary.gradeWeights[grade] ?? 0).toStringAsFixed(2)} kg',
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Weight by species',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    if (speciesEntries.isEmpty)
                      const Text('No species data available for today.')
                    else
                      ...speciesEntries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text(entry.key)),
                              const SizedBox(width: 12),
                              Text(
                                '${entry.value.toStringAsFixed(2)} kg',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

Future<_HarvestDetailsSummary> _loadHarvestDetails({String? date}) async {
  final resolvedDate = date ?? DateTime.now().toIso8601String().split('T').first;
  final response = await HarvestApi.fetchHarvestGradesByDate(date: resolvedDate);
  final rawRecords = response['data'];

  final records = <Map<String, dynamic>>[];
  if (rawRecords is List) {
    for (final item in rawRecords) {
      if (item is Map) {
        records.add(Map<String, dynamic>.from(item));
      }
    }
  }

  const grades = ['A', 'AB', 'B', 'C', 'CC', 'Z'];
  final gradeWeights = <String, double>{for (final grade in grades) grade: 0};
  gradeWeights['Unspecified'] = 0;
  final speciesWeights = <String, double>{};

  double totalWeight = 0;
  for (final record in records) {
    final weight = _parseWeight(record['weight']);
    totalWeight += weight;

    final grade = record['grade']?.toString().toUpperCase();
    if (grade != null && grade.isNotEmpty && gradeWeights.containsKey(grade)) {
      gradeWeights[grade] = gradeWeights[grade]! + weight;
    } else {
      gradeWeights['Unspecified'] = gradeWeights['Unspecified']! + weight;
    }

    final speciesLabel = _resolveSpeciesLabel(record);
    speciesWeights[speciesLabel] = (speciesWeights[speciesLabel] ?? 0) + weight;
  }

  return _HarvestDetailsSummary(
    date: resolvedDate,
    count: records.length,
    totalWeight: totalWeight,
    gradeWeights: gradeWeights,
    speciesWeights: speciesWeights,
  );
}

double _parseWeight(dynamic value) {
  if (value == null) return 0;
  return double.tryParse(value.toString()) ?? 0;
}

String _resolveSpeciesLabel(Map<String, dynamic> record) {
  final species = record['species'];
  if (species is Map) {
    final name = species['name']?.toString();
    if (name != null && name.isNotEmpty) return name;
  }

  final speciesId = record['species_id']?.toString();
  if (speciesId != null && speciesId.isNotEmpty) {
    return 'Species $speciesId';
  }

  return 'Unspecified species';
}
