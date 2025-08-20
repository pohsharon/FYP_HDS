// import 'package:flutter/material.dart';
// import 'package:qr_flutter/qr_flutter.dart';
// import 'package:fyp_hbs/theme/app_colors.dart';
// // import 'package:fyp_hbs/services/fruit_api.dart';
// // import 'package:fyp_hbs/fruit/create_fruit.dart';
// // import 'package:fyp_hbs/fruit/fruit_details.dart';

// class FruitPage extends StatefulWidget {
//   const FruitPage({super.key});

//   @override
//   State<FruitPage> createState() => _FruitPageState();
// }

// class _FruitPageState extends State<FruitPage> {
//   late Future<List<dynamic>> _fruitsFuture;
//   List<dynamic> fruits = [];
//   List<dynamic> _allFruits = [];
//   List<dynamic> _filteredFruits = [];
//   List<String> _speciesList = [];
//   String? _selectedSpecies;

//   @override
//   void initState() {
//     super.initState();
//     fetchFruits();
//   }

//   void fetchFruits() async {
//     try {
//       // fruits = await FruitApi.fetchFruits();
//       // final speciesSet = <String>{};
//       // for (var fruit in fruits) {
//       //   final speciesName = fruit['tree']?['species']?['name'] ?? 'Unknown Species';
//       //   if (speciesName != null) {
//       //     speciesSet.add(speciesName);
//       //   }
//       // }

//       // setState(() {
//       //   _fruitsFuture = Future.value(fruits);
//       //   _allFruits = fruits;
//       //   _filteredFruits = fruits;
//       //   _speciesList = speciesSet.toList();
//       // });
//     } catch (e) {
//       print('Failed to fetch fruits: $e');
//     }
//   }

//   void filterFruits(String query) {
//     final filtered = _allFruits.where((fruit) {
//       final fruitTag = fruit['fruit_tag']?.toString().toLowerCase() ?? '';
//       return fruitTag.contains(query.toLowerCase());
//     }).toList();
//     setState(() {
//       _filteredFruits = filtered;
//     });
//   }

//   void _showSpeciesFilterDialog(BuildContext context) {
//     String? tempSelectedSpecies = _selectedSpecies;

//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Text("Filter by Species"),
//           content: StatefulBuilder(
//             builder: (context, setStateDialog) {
//               return Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   DropdownButton<String>(
//                     isExpanded: true,
//                     hint: const Text("Select a species"),
//                     value: tempSelectedSpecies,
//                     onChanged: (value) {
//                       setStateDialog(() {
//                         tempSelectedSpecies = value;
//                       });
//                     },
//                     items: _speciesList.map((species) {
//                       return DropdownMenuItem<String>(
//                         value: species,
//                         child: Text(species),
//                       );
//                     }).toList(),
//                   ),
//                 ],
//               );
//             },
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 _clearSpeciesFilter();
//               },
//               child: const Text("Clear Filter"),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 if (tempSelectedSpecies != null) {
//                   _filterBySpecies(tempSelectedSpecies!);
//                 }
//               },
//               child: const Text("Apply"),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _filterBySpecies(String species) {
//     setState(() {
//       _selectedSpecies = species;
//       _filteredFruits = _allFruits.where((fruit) {
//         return fruit['tree']?['species']?['name'] == species;
//       }).toList();
//     });
//   }

//   void _clearSpeciesFilter() {
//     setState(() {
//       _selectedSpecies = null;
//       _filteredFruits = _allFruits;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Fruits",
//             style: TextStyle(
//               fontWeight: FontWeight.bold,
//               color: Colors.white,
//             )),
//         backgroundColor: AppColors.pakistanGreen,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: () {
//               fetchFruits();
//             },
//           ),
//         ],
//       ),
//       backgroundColor: AppColors.background,
//       body: SafeArea(
//         child: Column(
//           children: [
//             const SizedBox(height: 16),
//             _buildSearchBar(context),
//             const SizedBox(height: 16),
//             Expanded(
//               child: _filteredFruits.isEmpty
//                   ? const Center(child: Text("Loading..."))
//                   : ListView.builder(
//                       padding: const EdgeInsets.symmetric(horizontal: 16),
//                       itemCount: _filteredFruits.length,
//                       itemBuilder: (context, index) {
//                         final fruit = _filteredFruits[index];
//                         return _buildFruitCard(context, fruit: fruit);
//                       },
//                     ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       child: Row(
//         children: [
//           Expanded(
//             child: TextField(
//               onChanged: (value) {
//                 filterFruits(value);
//               },
//               decoration: InputDecoration(
//                 hintText: 'Search Fruit',
//                 hintStyle: TextStyle(color: AppColors.gray600, fontSize: 12),
//                 prefixIcon: const Icon(Icons.search),
//                 suffixIcon: GestureDetector(
//                   onTap: () => _showSpeciesFilterDialog(context),
//                   child: const Icon(Icons.filter_alt_outlined),
//                 ),
//                 filled: true,
//                 fillColor: AppColors.white,
//                 contentPadding: const EdgeInsets.symmetric(vertical: 0),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(30),
//                   borderSide: BorderSide(color: AppColors.gray400, width: 1.2),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(30),
//                   borderSide: BorderSide(
//                     color: AppColors.hunterGreen,
//                     width: 1.5,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 8),
//           GestureDetector(
//             onTap: () async {
//               // final result = await Navigator.push(
//               //   context,
//               //   MaterialPageRoute(builder: (_) => const CreateFruitPage()),
//               // );

//               // if (result == true) {
//               //   fetchFruits();
//               //   ScaffoldMessenger.of(context).showSnackBar(
//               //     const SnackBar(content: Text('Fruit list updated')),
//               //   );
//               // }
//             },
//             child: Container(
//               decoration: const BoxDecoration(
//                 color: AppColors.pakistanGreen,
//                 shape: BoxShape.circle,
//               ),
//               padding: const EdgeInsets.all(6),
//               child: const Icon(Icons.add, color: Colors.white),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFruitCard(
//     BuildContext context, {
//     required Map<String, dynamic> fruit,
//   }) {
//     final String tag = fruit['fruit_tag'] ?? 'Unknown';
//     final String species = fruit['tree']?['species']?['name'] ?? 'Unknown Species';
//     final String weight = fruit['weight']?.toString() ?? 'Unknown';
//     final String grade = fruit['grade'] ?? 'Unknown';
//     final String treeTag = fruit['tree']?['tree_tag'] ?? 'Unknown';
//     final String uuid = fruit['uuid'];

//     return Card(
//       color: AppColors.white,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//         side: BorderSide(color: AppColors.gray400),
//       ),
//       margin: const EdgeInsets.only(bottom: 10),
//       elevation: 0,
//       child: Padding(
//         padding: const EdgeInsets.all(10),
//         child: Row(
//           children: [
//             // QR Code
//             SizedBox(
//               width: 70,
//               height: 70,
//               child: QrImageView(data: uuid, version: QrVersions.auto),
//             ),
//             const SizedBox(width: 12),
//             // Fruit info
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     tag,
//                     style: const TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 16,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     "Species: $species",
//                     style: const TextStyle(
//                       color: Colors.grey,
//                       fontSize: 11,
//                     ),
//                   ),
//                   Text(
//                     "Weight: $weight kg | Grade: $grade",
//                     style: const TextStyle(
//                       color: Colors.grey,
//                       fontSize: 11,
//                     ),
//                   ),
//                   Text(
//                     "Tree: $treeTag",
//                     style: const TextStyle(
//                       color: Colors.grey,
//                       fontSize: 11,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             // View Button
//             OutlinedButton(
//               onPressed: () async {
//                 // final shouldRefresh = await Navigator.push(
//                 //   context,
//                 //   MaterialPageRoute(
//                 //     builder: (_) => FruitDetailsPage(fruitID: fruit['id'].toString()),
//                 //   ),
//                 // );
//                 // if (shouldRefresh == true) {
//                 //   fetchFruits();
//                 // }
//               },
//               style: OutlinedButton.styleFrom(
//                 foregroundColor: AppColors.hunterGreen,
//                 side: const BorderSide(color: AppColors.hunterGreen),
//                 minimumSize: const Size(60, 30),
//                 padding: const EdgeInsets.symmetric(horizontal: 12),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 textStyle: const TextStyle(fontSize: 12),
//               ),
//               child: const Text("View"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fyp_hbs/theme/app_colors.dart';

class FruitPage extends StatefulWidget {
  const FruitPage({super.key});

  @override
  State<FruitPage> createState() => _FruitPageState();
}

class _FruitPageState extends State<FruitPage> {
  List<Map<String, dynamic>> fruits = [
    {
      'fruit_tag': 'FR001',
      'uuid': 'uuid-fr001',
      'weight': 2.5,
      'grade': 'A',
      'tree': {
        'tree_tag': 'T001',
        'species': {'name': 'Musang King'}
      }
    },
    {
      'fruit_tag': 'FR002',
      'uuid': 'uuid-fr002',
      'weight': 3.1,
      'grade': 'B',
      'tree': {
        'tree_tag': 'T002',
        'species': {'name': 'D24'}
      }
    },
    {
      'fruit_tag': 'FR003',
      'uuid': 'uuid-fr003',
      'weight': 2.8,
      'grade': 'A',
      'tree': {
        'tree_tag': 'T001',
        'species': {'name': 'Musang King'}
      }
    },
  ];

  List<Map<String, dynamic>> _allFruits = [];
  List<Map<String, dynamic>> _filteredFruits = [];
  List<String> _speciesList = [];
  String? _selectedSpecies;

  @override
  void initState() {
    super.initState();
    _initializeMockData();
  }

  void _initializeMockData() {
    _allFruits = fruits;
    _filteredFruits = fruits;

    final speciesSet = <String>{};
    for (var fruit in fruits) {
      final speciesName = fruit['tree']?['species']?['name'] ?? 'Unknown Species';
      speciesSet.add(speciesName);
    }
    _speciesList = speciesSet.toList();
  }

  void filterFruits(String query) {
    final filtered = _allFruits.where((fruit) {
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
                items: _speciesList.map((species) {
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
      _filteredFruits = _allFruits.where((fruit) {
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
        title: const Text("Fruits",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            )),
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
              child: _filteredFruits.isEmpty
                  ? const Center(child: Text("No fruits found"))
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
        ],
      ),
    );
  }

  Widget _buildFruitCard(
    BuildContext context, {
    required Map<String, dynamic> fruit,
  }) {
    final String tag = fruit['fruit_tag'] ?? 'Unknown';
    final String species = fruit['tree']?['species']?['name'] ?? 'Unknown Species';
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
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    "$weight kg | Grade $grade",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('View fruit: $tag')),
                );
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
