import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/fruit/create_fruit.dart';
import 'package:fyp_hbs/services/api/fruit_api.dart';
import 'package:fyp_hbs/tree/tree_details.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchFruits();
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
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading fruits: $e")));
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

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Filter by Species"),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return DropdownButton<String>(
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
      appBar: AppBar(
        title: const Text(
          "Fruits",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.pakistanGreen,
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildSearchBar(context),
            const SizedBox(height: 16),
            Expanded(
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fruit list updated')),
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

  Widget _buildFruitCard(
    BuildContext context, {
    required Map<String, dynamic> fruit,
  }) {
    final String tag = fruit['fruit_tag'] ?? 'Unknown';
    final String species =
        fruit['tree']?['species']?['name'] ?? 'Unknown Species';
    final String weight = fruit['weight']?.toString() ?? 'Unknown';
    final String grade = fruit['grade'] ?? 'Unknown';
    final String treeTag = fruit['tree']?['tree_tag'] ?? 'Unknown';
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
                    // Text(
                    //   treeTag,
                    //   style: const TextStyle(
                    //     color: Colors.grey,
                    //     fontSize: 11,
                    //   ),
                    // ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  _showFruitDetailsDialog(context, fruit);
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
