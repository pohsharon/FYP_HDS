import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/home/species/create_species.dart';
import 'package:fyp_hbs/home/species/model/species.dart';
import 'package:fyp_hbs/services/species_api.dart';

class SpeciesListPage extends StatefulWidget {
  const SpeciesListPage({super.key});

  @override
  State<SpeciesListPage> createState() => _SpeciesListPageState();
}

class _SpeciesListPageState extends State<SpeciesListPage> {
  List<Species> _allSpecies = [];
  List<Species> _filteredSpecies = [];

  @override
  void initState() {
    super.initState();
    fetchSpecies();
  }

  void fetchSpecies() async {
    final speciesList = await SpeciesApi.fetchSpecies();
    setState(() {
      _allSpecies = speciesList;
      _filteredSpecies = speciesList;
    });
  }

  void _filterSpecies(String query) {
    final filtered =
        _allSpecies.where((species) {
          final lowerQuery = query.toLowerCase();
          return species.code.toLowerCase().contains(lowerQuery) ||
              species.name.toLowerCase().contains(lowerQuery);
        }).toList();

    setState(() {
      _filteredSpecies = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Species List',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: 16.0,
            ),
            child: Tooltip(
              message:
                  'Tap once to view description, long press to edit or delete',
              child: Icon(Icons.info_outline, color: Colors.grey),
            ),
          ),
        ],

        backgroundColor: AppColors.pakistanGreen,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildSearchBar(context),
            const SizedBox(height: 16),
            Expanded(
              child:
                  _allSpecies.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredSpecies.isEmpty
                      ? const Center(child: Text('No species found.'))
                      : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredSpecies.length,
                        itemBuilder: (context, index) {
                          final species = _filteredSpecies[index];
                          return _buildSpeciesCard(context, species);
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
          const SizedBox(width: 5),
          Expanded(
            child: TextField(
              onChanged: (value) => _filterSpecies(value),
              decoration: InputDecoration(
                hintText: 'Search Species Code',
                hintStyle: TextStyle(color: AppColors.gray600, fontSize: 12),
                prefixIcon: const Icon(Icons.search),
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
                MaterialPageRoute(builder: (_) => const CreateSpeciesPage()),
              );

              if (result == true) {
                setState(() {
                  fetchSpecies();
                });
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

  Widget _buildSpeciesCard(BuildContext context, Species species) {
    return GestureDetector(
      onTap: () {
        if ((species.description ?? '').trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No description available.'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text(species.name),
                  content: Text(species.description ?? ''),
                  actions: [
                    TextButton(
                      child: const Text('Close'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
          );
        }
      },
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder:
              (_) => Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8), // Add spacing at the top
                    ListTile(
                      leading: const Icon(Icons.edit),
                      title: const Text('Edit'),
                      onTap: () async {
                        Navigator.pop(context); // Close the bottom sheet
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateSpeciesPage(species: species),
                          ),
                        );
                        if (result == true) fetchSpecies();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete),
                      title: const Text('Delete'),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Confirm Delete'),
                                content: const Text(
                                  'Are you sure you want to delete this species?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, true),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                        );

                        if (confirm == true) {
                          try {
                            final response = await SpeciesApi.deleteSpecies(
                              species.id.toString(),
                            );

                            if (context.mounted) {
                              fetchSpecies();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Deleted successfully")),
                              );
                              Navigator.pop(
                                context,
                                true,
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Delete failed: ${e.toString()}",
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
        );
      },
      child: Card(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.gray400),
        ),
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          species.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      species.code,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                species.treeCount.toString(),
                style: const TextStyle(
                  color: AppColors.gray800,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
