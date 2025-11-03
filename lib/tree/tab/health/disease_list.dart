import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/disease_api.dart';
import 'package:fyp_hbs/tree/tab/health/create_disease.dart';

class DiseaseListPage extends StatefulWidget {
  const DiseaseListPage({super.key});

  @override
  State<DiseaseListPage> createState() => _DiseaseListPageState();
}

class _DiseaseListPageState extends State<DiseaseListPage> {
  late Future<List<Map<String, dynamic>>> _futureDiseases;

  @override
  void initState() {
    super.initState();
    _futureDiseases = DiseaseApi.fetchDiseases();
  }

  Future<void> _reload() async {
    setState(() {
      _futureDiseases = DiseaseApi.fetchDiseases();
    });
    await _futureDiseases;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Disease List',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: AppColors.pakistanGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              // ✅ When adding new disease, pass null for existingDisease
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateDiseasePage(
                    treeTag: "",
                    treeUuid: "",
                  ),
                ),
              );
              if (result == true) _reload();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _futureDiseases,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 60),
                  Center(child: Text('Error: ${snapshot.error}')),
                ],
              );
            }

            final diseases = snapshot.data ?? [];
            if (diseases.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 60),
                  Center(child: Text('No diseases found')),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: diseases.length,
              itemBuilder: (context, index) {
                final d = diseases[index];
                final name = (d['diseaseName'] ?? d['name'] ?? '').toString();
                final symptoms = (d['symptoms'] ?? '').toString();
                final remarks =
                    (d['remarks'] ?? d['description'] ?? '').toString();

                return GestureDetector(
                  onTap: () async {
                    // ✅ When editing, pass the tapped disease record
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateDiseasePage(
                          disease: d,
                          treeTag: "",
                          treeUuid: "",
                        ),
                      ),
                    );
                    if (result == true) _reload();
                  },
                  child: Card(
                    color: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.gray400),
                    ),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            symptoms,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Remark: $remarks',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.gray600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
