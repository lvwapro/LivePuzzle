import 'package:flutter/material.dart';
import 'package:live_puzzle/models/puzzle_project.dart';
import 'package:live_puzzle/models/frame_data.dart';

/// 拼图画布组件
/// 用于显示和编辑拼图布局
class PuzzleCanvas extends StatefulWidget {
  final PuzzleProject project;
  final int? selectedCellIndex;
  final ValueChanged<int>? onCellTap;
  final bool interactive;

  const PuzzleCanvas({
    Key? key,
    required this.project,
    this.selectedCellIndex,
    this.onCellTap,
    this.interactive = true,
  }) : super(key: key);

  @override
  State<PuzzleCanvas> createState() => _PuzzleCanvasState();
}

class _PuzzleCanvasState extends State<PuzzleCanvas> {
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: widget.project.layout.backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(
            widget.project.layout.borderRadius,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // 绘制所有单元格
                for (int i = 0; i < widget.project.layout.cells.length; i++)
                  _buildCell(i, constraints),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCell(int index, BoxConstraints constraints) {
    final cell = widget.project.layout.cells[index];
    final isSelected = widget.selectedCellIndex == index;
    
    // 查找该位置的帧
    final frameData = _getFrameForPosition(index);

    // 计算单元格的实际位置和大小
    final left = cell.rect.left * constraints.maxWidth;
    final top = cell.rect.top * constraints.maxHeight;
    final width = cell.rect.width * constraints.maxWidth;
    final height = cell.rect.height * constraints.maxHeight;

    final spacing = widget.project.layout.spacing;

    return Positioned(
      left: left + spacing / 2,
      top: top + spacing / 2,
      width: width - spacing,
      height: height - spacing,
      child: GestureDetector(
        onTap: widget.interactive
            ? () => widget.onCellTap?.call(index)
            : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade300,
              width: isSelected ? 3 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: frameData != null
                ? Transform.rotate(
                    angle: cell.rotation,
                    child: Image.memory(
                      frameData.imageData,
                      fit: BoxFit.cover,
                    ),
                  )
                : Container(
                    color: Colors.grey.shade200,
                    child: Center(
                      child: Icon(
                        Icons.add_photo_alternate,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  FrameData? _getFrameForPosition(int position) {
    try {
      final frame = widget.project.frames.firstWhere(
        (f) => f.positionInPuzzle == position,
      );
      return frame.frameData;
    } catch (e) {
      return null;
    }
  }
}
