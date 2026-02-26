import 'package:flutter/material.dart';
import 'package:live_puzzle/screens/home_screen.dart';
import 'package:live_puzzle/screens/settings_screen.dart';

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
    const DiscoverScreen(),
    const SettingsScreen(showBackButton: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white.withOpacity(0.9),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 40),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: Colors.white.withOpacity(0.8),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF85A2).withOpacity(0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home, 'Home', 0),
                  _buildNavItem(Icons.explore, 'Discover', 1),
                  _buildNavItem(Icons.settings, 'Settings', 2),
                ],
              ),
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
            size: isActive ? 36 : 32,
            weight: 700,
            color: isActive ? const Color(0xFFFF85A2) : const Color(0xFFFFC1CC),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: isActive ? const Color(0xFFFF85A2) : const Color(0xFFFFC1CC),
            ),
          ),
        ],
      ),
    );
  }
}

/// 发现页面（占位）
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F3),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF85A2).withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.explore,
                  size: 60,
                  color: Color(0xFFFF85A2),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Discover',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF85A2),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '发现更多精彩内容',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '功能开发中...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
