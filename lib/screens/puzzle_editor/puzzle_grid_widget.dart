import 'package:flutter/material.dart';
import 'puzzle_cell_widget.dart';
import 'dart:typed_data';

/// 拼图网格组件 - FULL 长图拼接布局
class PuzzleGridWidget extends StatelessWidget {
  final int selectedCellIndex;
  final Map<int, Uint8List?> cellImages;
  final int photoCount;
  final Function(int) onCellTap;
  final VoidCallback onBackgroundTap;
  final Function(int fromIndex, int toIndex)? onReorder;  // 🔥 拖拽重排回调

  const PuzzleGridWidget({
    super.key,
    required this.selectedCellIndex,
    required this.cellImages,
    required this.photoCount,
    required this.onCellTap,
    required this.onBackgroundTap,
    this.onReorder,  // 可选
  });

  @override
  Widget build(BuildContext context) {
    // 🔥 整个区域都可以点击取消选中
    // 只有点击图片本身时才会选中（由 PuzzleCell 的 GestureDetector 处理）
    return GestureDetector(
      behavior: HitTestBehavior.translucent,  // 🔥 允许点击穿透到下层
      onTap: onBackgroundTap,  // 点击任何非图片区域都取消选中
      child: Center(
        child: _buildLongImageLayout(),
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

    // 🔥 自由布局，设置固定宽度让图片可以被缩放
    return SizedBox(
      width: 360,  // 固定宽度，作为缩放的基准
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
        onReorder: onReorder,  // 🔥 传递重排回调
      ),
    );
  }
}
