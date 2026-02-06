import 'package:flutter/material.dart';
import 'package:live_puzzle/models/puzzle_layout.dart';

/// 布局模板选择器
class LayoutTemplates extends StatelessWidget {
  final LayoutType selectedType;
  final ValueChanged<LayoutType> onLayoutSelected;

  const LayoutTemplates({
    Key? key,
    required this.selectedType,
    required this.onLayoutSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            '选择布局',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildLayoutOption(
                context,
                LayoutType.grid2x2,
                '2x2网格',
                Icons.grid_4x4,
              ),
              _buildLayoutOption(
                context,
                LayoutType.grid3x3,
                '3x3网格',
                Icons.grid_on,
              ),
              _buildLayoutOption(
                context,
                LayoutType.grid2x3,
                '2x3网格',
                Icons.view_module,
              ),
              _buildLayoutOption(
                context,
                LayoutType.collageHorizontal,
                '横向拼贴',
                Icons.view_day,
              ),
              _buildLayoutOption(
                context,
                LayoutType.collageVertical,
                '纵向拼贴',
                Icons.view_agenda,
              ),
              _buildLayoutOption(
                context,
                LayoutType.freeForm,
                '自由排列',
                Icons.crop_free,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLayoutOption(
    BuildContext context,
    LayoutType type,
    String label,
    IconData icon,
  ) {
    final isSelected = selectedType == type;
    return GestureDetector(
      onTap: () => onLayoutSelected(type),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: isSelected ? Colors.blue : Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.blue : Colors.grey.shade800,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
