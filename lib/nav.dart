import 'package:flutter/material.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/tree/tree_list.dart';
import 'package:fyp_hbs/QR.dart';
import 'package:fyp_hbs/fruit/fruit_list.dart';

class Nav extends StatefulWidget {
  const Nav({super.key});

  @override
  State<Nav> createState() => _NavState();
}

class _NavState extends State<Nav> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    TreePage(),
    FruitPage()
  ];

  final Color activeColor = AppColors.hunterGreen;
  final Color inactiveColor = AppColors.black;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onFabPressed() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const QRScannerPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: activeColor,
        onPressed: _onFabPressed,
        tooltip: 'Scan QR',
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        color: AppColors.white,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              // _buildTabIcon(Icons.home, 'Home', 0),
              _buildTabIcon(Icons.nature, 'Tree', 0),
              const SizedBox(width: 48), 
              _buildTabIcon(Icons.bar_chart, 'Fruit', 1),
              // _buildTabIcon(Icons.settings, 'Settings', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabIcon(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    final color = isSelected ? AppColors.hunterGreen : AppColors.black;
    final fontWeight = isSelected ? FontWeight.bold : FontWeight.normal;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: fontWeight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}