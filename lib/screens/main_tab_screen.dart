import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

// New — Profile is a real tab now, not a Home tile, per direction: "not a regression, a
// necessity." Home stays exactly as it was; Board/Achievements stays parked for later, per the
// explicit instruction not to bring that back yet. IndexedStack keeps both screens alive
// underneath (rather than rebuilding Profile from scratch every time you switch to it), same
// low-risk approach as everywhere else in this app that swaps content without losing state.
class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});
  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(
        index: _tabIndex,
        children: const [HomeScreen(), ProfileScreen()],
      ),
      // Standard Flutter BottomNavigationBar rather than something custom-built — lower risk,
      // same treatment across both tabs by construction, which is the actual point of the
      // consistency requirement, not just visually similar screens reached two different ways.
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        backgroundColor: AppColors.bg2,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: AppColors.textSoft,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
