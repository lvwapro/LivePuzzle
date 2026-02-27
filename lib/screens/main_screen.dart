import 'package:flutter/material.dart';
import 'package:live_puzzle/screens/home_screen.dart';
import 'package:live_puzzle/screens/settings_screen.dart';
import 'package:live_puzzle/l10n/app_localizations.dart';

/// 主页面容器 - 包含底部导航栏
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const SettingsScreen(showBackButton: false),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 8, 40, 20),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home, l10n.home, 0),
                _buildNavItem(Icons.settings, l10n.settings, 1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isActive ? 28 : 24,
            weight: 700,
            color: isActive ? const Color(0xFFFF85A2) : const Color(0xFFFFC1CC),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: isActive ? const Color(0xFFFF85A2) : const Color(0xFFFFC1CC),
            ),
          ),
        ],
      ),
    );
  }
}
