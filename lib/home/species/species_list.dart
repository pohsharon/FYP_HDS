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
  late Future<List<Species>> futureSpecies;

  @override
  void initState() {
    super.initState();
    futureSpecies = SpeciesApi.fetchSpecies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Species List', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
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
              child: FutureBuilder<List<Species>>(
                future: futureSpecies,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No species found.'));
                  }

                  final speciesList = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: speciesList.length,
                    itemBuilder: (context, index) {
                      final species = speciesList[index];
                      return _buildSpeciesCard(
                        context,
                        name: species.name,
                        code: species.code,
                        description: species.description ?? '',
                        treeCount: species.treeCount.toString(),
                        status: species.isActive ? 'Inactive' : 'Active',
                      );
                    },
                  );
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
              decoration: InputDecoration(
                hintText: 'Search Species Code',
                hintStyle: TextStyle(color: AppColors.gray600, fontSize: 12),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: const Icon(Icons.filter_alt_outlined),
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CreateSpeciesPage()),
              );
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

  Widget _buildSpeciesCard(
    BuildContext context, {
    required String name,
    required String code,
    required String description,
    required String treeCount,
    required String status,
  }) {
    Color statusColor = status == 'Active' ? AppColors.successLight : AppColors.dangerLight;
    Color statusTextColor = status == 'Active' ? AppColors.successActive : AppColors.dangerActive;

    return GestureDetector(
      onTap: () {
        if (description.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No description available.'), duration: Duration(seconds: 2)),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(name),
              content: Text(description),
              actions: [
                TextButton(child: const Text('Close'), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          );
        }
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
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusTextColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(code, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(treeCount, style: const TextStyle(color: AppColors.gray800, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
