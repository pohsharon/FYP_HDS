import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/buyer/create_buyer.dart';
import 'package:fyp_hbs/buyer/buyer_details.dart';
import 'package:fyp_hbs/services/buyer_api.dart';

class BuyerPage extends StatefulWidget {
  const BuyerPage({super.key});

  @override
  State<BuyerPage> createState() => _BuyerPageState();
}

class _BuyerPageState extends State<BuyerPage> {
  List<Map<String, dynamic>> buyers = [];
  List<Map<String, dynamic>> allBuyers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBuyers();
  }

  Future<void> _loadBuyers() async {
    try {
      final fetchedBuyers = await BuyerApi.fetchBuyers();
      setState(() {
        allBuyers = fetchedBuyers;
        buyers = fetchedBuyers;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void filterBuyers(String query) {
    if (query.isEmpty) {
      setState(() => buyers = allBuyers);
    } else {
      final filtered =
          allBuyers.where((buyer) {
            final company = buyer['company_name']?.toLowerCase() ?? '';
            final contactName = buyer['contact_name']?.toLowerCase() ?? '';
            return company.contains(query.toLowerCase()) ||
                contactName.contains(query.toLowerCase());
          }).toList();
      setState(() => buyers = filtered);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buyers', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.pakistanGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBuyers,
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
              child:
                  buyers.isEmpty
                      ? const Center(child: Text("No buyers found"))
                      : isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: buyers.length,
                        itemBuilder: (context, index) {
                          final buyer = buyers[index];
                          return _buildBuyerCard(context, buyer: buyer);
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
          const Icon(
            Icons.receipt_long_rounded,
            color: AppColors.successActive,
            size: 30,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: TextField(
              onChanged: (value) {
                filterBuyers(value);
              },
              decoration: InputDecoration(
                hintText: 'Search Buyer',
                hintStyle: TextStyle(color: AppColors.gray600, fontSize: 12),
                prefixIcon: const Icon(Icons.search),
                // suffixIcon: const Icon(Icons.filter_alt_outlined),
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
                MaterialPageRoute(builder: (context) => CreateBuyerPage()),
              ).then((value) {
                if (value == true) {
                  _loadBuyers();
                }
              });
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

  Widget _buildBuyerCard(
    BuildContext context, {
    required Map<String, dynamic> buyer,
  }) {
    final String company = buyer['company_name'] ?? '';
    final String location = buyer['address'] ?? '';
    final String pic = buyer['contact_name'] ?? '';
    final String phone = buyer['contact_number']?.toString() ?? '';
    final String email = buyer['email'] ?? '';
    final String uuid = buyer['uuid'] ?? '';
    final String id = buyer['id']?.toString() ?? '';
    return Card(
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
            const SizedBox(width: 10),
            // Tree info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        company,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        location,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(),
            // View Button
            OutlinedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BuyerDetailsPage(buyer: buyer),
                  ),
                );

                if (result == true) {
                  _loadBuyers(); // ✅ Refresh the list after deletion
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Buyer deleted successfully')),
                  );
                }
              },

              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.hunterGreen,
                side: const BorderSide(color: AppColors.hunterGreen),
                minimumSize: const Size(60, 30), // Smaller height
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
