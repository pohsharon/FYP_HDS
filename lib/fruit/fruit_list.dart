import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/fruit/create_fruit.dart';
import 'package:fyp_hbs/services/api/fruit_api.dart';
import 'package:fyp_hbs/models/tree_model.dart';
import 'package:fyp_hbs/tree/tree_details.dart';
import 'package:fyp_hbs/services/local database/fruit_db.dart';
import 'package:fyp_hbs/services/local database/tree_db.dart';
import 'package:fyp_hbs/services/local database/species_db.dart';
import 'package:fyp_hbs/widgets/persistent_appbar.dart';
import 'dart:math';
import 'package:another_flushbar/flushbar.dart';
import 'package:fyp_hbs/services/api/auth_service.dart';
import 'package:fyp_hbs/authentication/reset_password.dart';
import 'package:fyp_hbs/authentication/login.dart';

class FruitPage extends StatefulWidget {
  const FruitPage({super.key});

  @override
  State<FruitPage> createState() => _FruitPageState();
}

class _FruitPageState extends State<FruitPage> {
  List<Map<String, dynamic>> _allFruits = [];
  List<Map<String, dynamic>> _filteredFruits = [];
  List<String> _speciesList = [];
  String? _selectedSpecies;
  final TextEditingController _speciesFilterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchFruits();
  }

  @override
  void dispose() {
    _speciesFilterController.dispose();
    super.dispose();
  }

  Future<void> fetchFruits() async {
    try {
      final fruits = await FruitApi.fetchFruits();

      final speciesSet = <String>{};
      for (var fruit in fruits) {
        final speciesName =
            fruit['tree']?['species']?['name'] ?? 'Unknown Species';
        speciesSet.add(speciesName);
      }

      setState(() {
        _allFruits = fruits;
        _filteredFruits = fruits;
        _speciesList = speciesSet.toList();
      });
    } catch (e) {
      // On error (likely offline), try to load fruits from local DB cache
      try {
        final localFruits = await FruitDB().getAllFruits();
        // build tree/species lookup to populate nested fields similar to API shape
        final localTrees = await TreeDB().fetchAllTrees();
        final speciesRows = await SpeciesDB().getAllSpecies();
        final Map<String, String> speciesLookup = {};
        for (final s in speciesRows) {
          final key = s['id']?.toString();
          final name = s['name']?.toString() ?? '';
          if (key != null) speciesLookup[key] = name;
        }

        final Map<String, TreeModel> treeByUuid = {};
        for (final t in localTrees) {
          treeByUuid[t.uuid] = t;
        }

        final mapped =
            localFruits.map((f) {
              final treeUuid = f.tree_uuid;
              String speciesName = 'Unknown Species';
              String treeTag = 'Offline Tree';
              if (treeUuid != null && treeByUuid.containsKey(treeUuid)) {
                final tm = treeByUuid[treeUuid]!;
                final sid = tm.speciesId?.toString();
                if (sid != null && speciesLookup.containsKey(sid)) {
                  speciesName = speciesLookup[sid]!;
                } else if (tm.speciesId != null) {
                  speciesName = tm.speciesId.toString();
                }
                treeTag = tm.treeTag ?? treeTag;
              }

              // Prefer an explicit persisted fruit_tag if available, otherwise fall
              // back to grade, harvested date, or short harvest uuid for readability.
              String fruitTag =
                  (f.fruit_tag != null && f.fruit_tag!.isNotEmpty)
                      ? f.fruit_tag!
                      : (() {
                        if (f.grade != null && f.grade!.isNotEmpty) {
                          return 'Grade ${f.grade}';
                        } else if (f.harvested_at != null &&
                            f.harvested_at!.isNotEmpty) {
                          return f.harvested_at!;
                        } else if (f.harvest_uuid != null &&
                            f.harvest_uuid!.isNotEmpty) {
                          final id = f.harvest_uuid!;
                          return id.length > 8 ? id.substring(0, 8) : id;
                        } else {
                          return 'Offline Fruit';
                        }
                      })();

              return {
                'uuid': f.harvest_uuid ?? '',
                'fruit_tag': fruitTag,
                'harvested_at': f.harvested_at ?? '',
                'weight': f.weight,
                'grade': f.grade ?? '',
                'tree': {
                  'uuid': treeUuid ?? '',
                  'tree_tag': treeTag,
                  'species': {'name': speciesName},
                },
              };
            }).toList();

        final mappedList = mapped.cast<Map<String, dynamic>>().toList();

        setState(() {
          _allFruits = mappedList;
          _filteredFruits = mappedList;
          _speciesList =
              mappedList
                  .map(
                    (e) =>
                        (e['tree']
                                as Map<String, dynamic>?)?['species']?['name']
                            ?.toString() ??
                        'Unknown',
                  )
                  .toSet()
                  .toList();
        });
      } catch (e2) {
        setState(() {});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading fruits: $e")));
      }
    }
  }

  void filterFruits(String query) {
    final filtered =
        _allFruits.where((fruit) {
          final fruitTag = fruit['fruit_tag']?.toString().toLowerCase() ?? '';
          return fruitTag.contains(query.toLowerCase());
        }).toList();
    setState(() {
      _filteredFruits = filtered;
    });
  }

  void _showSpeciesFilterDialog(BuildContext context) {
    String? tempSelectedSpecies = _selectedSpecies;

    _speciesFilterController.text = tempSelectedSpecies ?? '';

    showDialog(
      context: context,
      builder: (context) {
        final dialogWidth = min(MediaQuery.of(context).size.width * 0.9, 520.0);

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: dialogWidth),
              child: StatefulBuilder(
                builder: (context, setStateDialog) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top:10, bottom: 8.0),
                        child: Text(
                          'Filter by Species',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(
                        width: dialogWidth,
                        child: Builder(builder: (context) {
                          // local open state for the pseudo-dropdown
                          bool isOpen = false;
                          return StatefulBuilder(
                            builder: (context, setStateDialogInner) {
                              final displayText = tempSelectedSpecies ?? 'Select a species';
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  GestureDetector(
                                    onTap: () => setStateDialogInner(() => isOpen = !isOpen),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade400),
                                        color: Colors.white,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(displayText, style: const TextStyle(color: Colors.black87)),
                                          ),
                                          Icon(isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: Colors.black54),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isOpen)
                                    const SizedBox(height: 8),
                                  if (isOpen)
                                    Material(
                                      elevation: 4,
                                      borderRadius: BorderRadius.circular(8),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(maxHeight: 260, minWidth: dialogWidth, maxWidth: dialogWidth),
                                        child: ListView.separated(
                                          shrinkWrap: true,
                                          itemCount: _speciesList.length,
                                          separatorBuilder: (_, __) => const Divider(height: 1),
                                          itemBuilder: (context, idx) {
                                            final species = _speciesList[idx];
                                            return InkWell(
                                              onTap: () {
                                                setStateDialogInner(() {
                                                  tempSelectedSpecies = species;
                                                  _speciesFilterController.text = species;
                                                  isOpen = false;
                                                });
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                                child: Text(species),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _clearSpeciesFilter();
                            },
                            child: const Text('Clear Filter'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              if (tempSelectedSpecies != null) {
                                _filterBySpecies(tempSelectedSpecies!);
                              }
                            },
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _filterBySpecies(String species) {
    setState(() {
      _selectedSpecies = species;
      _filteredFruits =
          _allFruits.where((fruit) {
            return fruit['tree']?['species']?['name'] == species;
          }).toList();
    });
  }

  void _clearSpeciesFilter() {
    setState(() {
      _selectedSpecies = null;
      _filteredFruits = _allFruits;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PersistentAppBar(
        title: 'Fruits',
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            showModalBottomSheet(
              context: context,
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
                      leading: const Icon(Icons.lock),
                      title: const Text('Change Password'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ResetPasswordPage(fromSettings: true),
                          ),
                        );
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
                          builder: (context) => AlertDialog(
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
                                icon: const Icon(Icons.check_circle, color: Colors.white),
                                backgroundColor: Colors.green.shade700,
                                duration: const Duration(seconds: 2),
                                borderRadius: BorderRadius.circular(8),
                                margin: const EdgeInsets.all(12),
                              ).show(context);
                            } else {
                              await Flushbar(
                                message: 'Logged out (server revoke pending)',
                                icon: const Icon(Icons.info, color: Colors.white),
                                backgroundColor: Colors.orange.shade700,
                                duration: const Duration(seconds: 2),
                                borderRadius: BorderRadius.circular(8),
                                margin: const EdgeInsets.all(12),
                              ).show(context);
                            }

                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => LoginPage()),
                              (route) => false,
                            );
                          } catch (e) {
                            await Flushbar(
                              message: 'Logout failed: $e',
                              icon: const Icon(Icons.error, color: Colors.white),
                              backgroundColor: Colors.red.shade700,
                              duration: const Duration(seconds: 3),
                              borderRadius: BorderRadius.circular(8),
                              margin: const EdgeInsets.all(12),
                            ).show(context);
                          }
                        }
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildSearchBar(context),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await fetchFruits();
                  // allow a short delay so UI updates smoothly
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child:
                    _filteredFruits.isEmpty
                        ? const Center(child: Text("Loading..."))
                        : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredFruits.length,
                          itemBuilder: (context, index) {
                            final fruit = _filteredFruits[index];
                            return _buildFruitCard(context, fruit: fruit);
                          },
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (value) {
                filterFruits(value);
              },
              decoration: InputDecoration(
                hintText: 'Search Fruit',
                hintStyle: TextStyle(color: AppColors.gray600, fontSize: 12),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: GestureDetector(
                  onTap: () => _showSpeciesFilterDialog(context),
                  child: const Icon(Icons.filter_alt_outlined),
                ),
                filled: true,
                fillColor: AppColors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: AppColors.gray400, width: 1.2),
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
                MaterialPageRoute(builder: (_) => const CreateFruitPage()),
              );

              if (result == true) {
                fetchFruits();
              }
            },
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.pakistanGreen,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFruitCard(
    BuildContext context, {
    required Map<String, dynamic> fruit,
  }) {
    final String tag = fruit['fruit_tag'] ?? 'Unknown';
    final String species =
        fruit['tree']?['species']?['name'] ?? 'Unknown Species';
    final String weight = fruit['weight']?.toString() ?? 'Unknown';
    final String grade = fruit['grade'] ?? 'Unknown';
    final String uuid = fruit['uuid'];

    return Card(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.gray400),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showFruitDetailsDialog(context, fruit),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: QrImageView(data: uuid, version: QrVersions.auto),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 0),
                    Text(
                      species,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    Text(
                      "$weight kg | Grade $grade",
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  _showFruitDetailsDialog(context, fruit);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 171, 149, 69),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(60, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text("View"),
              ),
            ],
          ),
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
    final String species = fruit['tree']?['species']?['name'] ?? '';
    final String treeTag = fruit['tree']?['tree_tag'] ?? '';
    final String? transactionId = fruit['transaction_id'];

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
                // Top row: close on the left, edit on the right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () async {
                        // Close details dialog then open edit page
                        Navigator.of(context).pop();
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateFruitPage(fruit: fruit),
                          ),
                        );
                        if (result == true) {
                          // refresh the list after editing
                          fetchFruits();
                        }
                      },
                    ),
                  ],
                ),
                // Tappable QR: open a white dialog like TreeDetails for preview
                GestureDetector(
                  onTap: () {
                    if (uuid.isEmpty) return;
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 100,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              QrImageView(
                                data: uuid,
                                version: QrVersions.auto,
                                size: 300,
                                gapless: true,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                uuid,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  child: QrImageView(
                    data: uuid,
                    version: QrVersions.auto,
                    size: 150,
                    gapless: true,
                  ),
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
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDetailRow("Date", date),
                _buildDetailRow("Weight", "$weight kg"),
                _buildDetailRow("Grade", grade),
                _buildDetailRow("Species", species),
                _buildDetailRow(
                  "Tree Origin",
                  treeTag,
                  underline: true,
                  onTap: () {
                    Navigator.of(context).pop(); // Close the dialog first
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => TreeDetailsPage(
                              treeID: fruit['tree']?['uuid'] ?? '',
                            ),
                      ),
                    );
                  },
                ),
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

  Widget _buildDetailRow(
    String label,
    String value, {
    bool underline = false,
    VoidCallback? onTap,
  }) {
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
                color: AppColors.black,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            child:
                underline
                    ? GestureDetector(
                      onTap: onTap,
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: AppColors.gray600,
                          decoration: TextDecoration.underline,
                          fontSize: 15,
                        ),
                      ),
                    )
                    : Text(
                      value,
                      style: const TextStyle(
                        color: AppColors.gray600,
                        fontSize: 15,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
