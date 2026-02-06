import 'package:flutter/material.dart';
import 'puzzle_cell_widget.dart';
import 'dart:typed_data';

/// 拼图网格组件 - FULL 长图拼接布局
class PuzzleGridWidget extends StatelessWidget {
  final int selectedCellIndex;
  final Map<int, Uint8List?> cellImages;
  final int photoCount;
  final Function(int) onCellTap;

  const PuzzleGridWidget({
    super.key,
    required this.selectedCellIndex,
    required this.cellImages,
    required this.photoCount,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    // 🔥 增加宽度以显示更清晰的图片
    const double fixedWidth = 360.0;
    
    return Center(
      child: Container(
        width: fixedWidth,
        height: 600.0,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF85A1).withOpacity(0.15),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: InteractiveViewer(
          minScale: 0.1,
          maxScale: 4.0,
          boundaryMargin: const EdgeInsets.all(100),
          constrained: false,
          child: _buildLongImageLayout(),
        ),
      ),
    );
  }

  Widget _buildLongImageLayout() {
    if (photoCount == 0) {
      return Container(
        width: 360,
        height: 280,
        color: Colors.grey.shade200,
        child: const Center(
          child: Text('请选择照片'),
        ),
      );
    }

    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          photoCount,
          (index) => _buildCell(index),
        ),
      ),
    );
  }

  Widget _buildCell(int index) {
    return IntrinsicHeight(
      child: PuzzleCell(
        index: index,
        imageData: cellImages[index],
        isSelected: selectedCellIndex == index,
        onTap: () => onCellTap(index),
      ),
    );
  }
}
