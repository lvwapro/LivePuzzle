import 'package:flutter/material.dart';

/// 功能按钮组件
class FeatureButtonsWidget extends StatelessWidget {
  const FeatureButtonsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildFeatureButton(
            icon: Icons.filter_vintage,
            label: 'Filters',
            onTap: () {
              // TODO: Implement filters
            },
          ),
          _buildFeatureButton(
            icon: Icons.emoji_emotions,
            label: 'Stickers',
            onTap: () {
              // TODO: Implement stickers
            },
          ),
          _buildFeatureButton(
            icon: Icons.palette,
            label: 'BG',
            onTap: () {
              // TODO: Implement background
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: const Color(0xFF4A3F44),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
