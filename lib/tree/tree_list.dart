import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/tree/tree_details.dart';
import 'package:fyp_hbs/tree/create_tree.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fyp_hbs/services/tree_api.dart';
import 'package:fyp_hbs/tree/map.dart';
import 'package:fyp_hbs/authentication/login.dart';

class TreePage extends StatefulWidget {
  const TreePage({super.key});

  @override
  State<TreePage> createState() => _TreePageState();
}

class _TreePageState extends State<TreePage> {
  late Future<List<dynamic>> _treesFuture;
  List<dynamic> trees = [];
  List<dynamic> _allTrees = [];
  List<dynamic> _filteredTrees = [];
  List<String> _speciesList = [];
  String? _selectedSpecies;

  @override
  void initState() {
    super.initState();
    fetchTrees();
  }

  void fetchTrees() async {
    try {
      trees = await TreeApi.fetchTrees();
      final speciesSet = <String>{};
      for (var tree in trees) {
        final speciesName = tree['species']?['name'] ?? 'Unknown Species';
        if (speciesName != null) {
          speciesSet.add(speciesName);
        }
      }

      setState(() {
        _treesFuture = Future.value(trees);
        _allTrees = trees;
        _filteredTrees = trees;
        _speciesList = speciesSet.toList();
      });
    } catch (e) {
      print('Failed to fetch trees: $e');
    }
  }

  void filterTrees(String query) {
    final filtered =
        _allTrees.where((tree) {
          final treeId = tree['tree_tag']?.toString().toLowerCase() ?? '';
          return treeId.contains(query.toLowerCase());
        }).toList();
    setState(() {
      _filteredTrees = filtered;
    });
  }

  void _showSpeciesFilterDialog(BuildContext context) {
    String? tempSelectedSpecies = _selectedSpecies;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Filter by Species"),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text("Select a species"),
                    value: tempSelectedSpecies,
                    onChanged: (value) {
                      setStateDialog(() {
                        tempSelectedSpecies = value;
                      });
                    },
                    items:
                        _speciesList.map((species) {
                          return DropdownMenuItem<String>(
                            value: species,
                            child: Text(species),
                          );
                        }).toList(),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearSpeciesFilter();
              },
              child: const Text("Clear Filter"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (tempSelectedSpecies != null) {
                  _filterBySpecies(tempSelectedSpecies!);
                }
              },
              child: const Text("Apply"),
            ),
          ],
        );
      },
    );
  }

  void _filterBySpecies(String species) {
    setState(() {
      _selectedSpecies = species;
      _filteredTrees =
          _allTrees.where((tree) {
            return tree['species']['name'] == species;
          }).toList();
    });
  }

  void _clearSpeciesFilter() {
    setState(() {
      _selectedSpecies = null;
      _filteredTrees = _allTrees;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Trees",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.pakistanGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
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
                // Clear authentication data here (e.g., SharedPreferences)
                // Example:
                // final prefs = await SharedPreferences.getInstance();
                // await prefs.clear();

                // Navigate to login page and remove all previous routes
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
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
                  fetchTrees();
                  // Wait for fetchTrees to complete and set state
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child:
                    _filteredTrees.isEmpty
                        ? const Center(child: Text("Loading..."))
                        : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredTrees.length,
                          itemBuilder: (context, index) {
                            final tree = _filteredTrees[index];
                            return _buildTreeCard(context, tree: tree);
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
          IconButton(
            icon: const Icon(
              Icons.location_on,
              color: AppColors.danger,
              size: 30,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapPage()),
              );
            },
          ),
          const SizedBox(width: 5),
          Expanded(
            child: TextField(
              onChanged: (value) {
                filterTrees(value);
              },
              decoration: InputDecoration(
                hintText: 'Search Tree',
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
                MaterialPageRoute(builder: (_) => const CreateTreePage()),
              );

              if (result == true) {
                fetchTrees();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tree list updated')),
                );
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

  Widget _buildTreeCard(
    BuildContext context, {
    required Map<String, dynamic> tree, // ✅ Accept tree map
  }) {
    final String tag = tree['tree_tag'];
    final String id = tree['id'].toString();
    final String type = tree['species']?['name'] ?? 'Unknown Species';
    final String date = tree['planted_at'];
    final String uuid = tree['uuid'];

    // Color statusColor =
    //     status == 'Flowering' ? AppColors.successLight : AppColors.dangerLight;
    // Color statusTextColor =
    //     status == 'Flowering'
    //         ? AppColors.successActive
    //         : AppColors.dangerActive;

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
        child: Row(
          children: [
            // QR Code
            SizedBox(
              width: 70,
              height: 70,
              child: QrImageView(data: uuid, version: QrVersions.auto),
            ),
            const SizedBox(width: 10),
            // Tree info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tag,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        type,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "•",
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // View Button
            OutlinedButton(
              onPressed: () async {
                final shouldRefresh = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => TreeDetailsPage(treeID: tree['id'].toString()),
                  ),
                );

                if (shouldRefresh == true) {
                  fetchTrees();
                }
              },
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
          ],
        ),
      ),
    );
  }
}
