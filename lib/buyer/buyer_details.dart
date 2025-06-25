import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/buyer_api.dart';
import 'package:fyp_hbs/buyer/create_buyer.dart';

class BuyerDetailsPage extends StatefulWidget {
  final Map<String, dynamic> buyer;

  const BuyerDetailsPage({super.key, required this.buyer});

  @override
  State<BuyerDetailsPage> createState() => _BuyerDetailsPageState();
}

class _BuyerDetailsPageState extends State<BuyerDetailsPage> {
  late Map<String, dynamic> _buyer;

  @override
  void initState() {
    super.initState();
    _buyer = Map<String, dynamic>.from(widget.buyer);
  }

  Future<void> _loadBuyerDetails() async {
    try {
      final updated = await BuyerApi.getBuyerId(_buyer['id'].toString());
      setState(() {
        _buyer = Map<String, dynamic>.from(updated);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to reload buyer details: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = _buyer['contact_name'] ?? 'No Name';
    final String phone = _buyer['contact_number']?.toString() ?? '-';
    final String email = _buyer['email'] ?? '-';
    final String location = _buyer['address'] ?? '-';
    final String companyName = _buyer['company_name'] ?? 'No Company';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            "Buyer Details",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: AppColors.pakistanGreen,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () async {
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateBuyerPage(buyer: _buyer),
                  ),
                );
                if (updated == true) {
                  _loadBuyerDetails(); // safely reload with UUID
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 15),
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              companyName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Detail Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _infoCard(label: 'Contact Person', value: name),
                  _infoCard(label: 'Contact Number', value: phone),
                  _infoCard(label: 'Email', value: email),
                  _infoCard(label: 'Location', value: location),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const TabBar(
              labelColor: AppColors.hunterGreen,
              unselectedLabelColor: Colors.grey,
              labelStyle: TextStyle(fontWeight: FontWeight.bold),
              indicatorColor: AppColors.hunterGreen,
              indicatorWeight: 2,
              tabs: [Tab(text: 'Overview'), Tab(text: 'Transaction History')],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  Center(child: Text('Overview Content')),
                  Center(child: Text('Transaction History Content')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({required String label, required String value}) {
    return SizedBox(
      width: 150,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
