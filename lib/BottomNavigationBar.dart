import 'package:flutter/material.dart';
import 'package:wa_inventory/CategoryOverviewScreen.dart';
import 'package:wa_inventory/HomeScreen.dart';
import 'package:wa_inventory/ItemsList.dart';
import 'package:wa_inventory/profileScreen.dart';
import 'package:wa_inventory/PurchaseDemandScreen.dart';
import 'package:wa_inventory/ReportPage.dart';

class BottomNavigationScreen extends StatefulWidget {
  const BottomNavigationScreen({super.key});

  @override
  _BottomNavigationScreenState createState() =>
      _BottomNavigationScreenState();
}

class _BottomNavigationScreenState extends State<BottomNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const CategoryOverviewScreen(),   // replaces old "Items" tab
    const PurchaseDemandScreen(),
    ReportPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageStorage(
        bucket: PageStorageBucket(),
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              width: 1.5,
              color: Color.fromRGBO(107, 59, 225, 1),
            ),
          ),
        ),
        child: BottomNavigationBar(
          showUnselectedLabels: true,
          currentIndex: _currentIndex,
          selectedItemColor: const Color.fromRGBO(107, 11, 232, 1),
          unselectedItemColor: const Color.fromRGBO(107, 59, 225, 0.55),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          iconSize: 27,
          unselectedFontSize: 11,
          selectedFontSize: 12,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.category_outlined),
              activeIcon: Icon(Icons.category),
              label: 'Categories',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined),
              activeIcon: Icon(Icons.shopping_cart),
              label: 'Purchase',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Report',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle_outlined),
              activeIcon: Icon(Icons.account_circle),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
