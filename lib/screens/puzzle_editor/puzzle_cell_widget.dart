import 'dart:typed_data';
import 'package:flutter/material.dart';

/// 拼图单元格组件
class PuzzleCell extends StatelessWidget {
  final int index;
  final Uint8List? imageData;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(int fromIndex, int toIndex)? onReorder;  // 🔥 拖拽重排回调

  const PuzzleCell({
    super.key,
    required this.index,
    required this.imageData,
    required this.isSelected,
    required this.onTap,
    this.onReorder,  // 可选
  });

  @override
  Widget build(BuildContext context) {
    final cellContent = Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected
              ? const Color(0xFFFF4D7D)
              : Colors.transparent,
          width: isSelected ? 3 : 0,
        ),
      ),
      child: Stack(
        children: [
          // 图片
          if (imageData != null)
            Image.memory(
              imageData!,
              fit: BoxFit.contain,
              width: double.infinity,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
            )
          else
            const SizedBox(
              height: 200,
              child: Center(
                child: Icon(
                  Icons.add_photo_alternate,
                  size: 40,
                  color: Colors.grey,
                ),
              ),
            ),
        ],
      ),
    );

    // 🔥 包装为可拖拽和可接收拖拽的组件
    if (onReorder != null && imageData != null) {
      return DragTarget<int>(
        onAcceptWithDetails: (details) {
          final fromIndex = details.data;
          if (fromIndex != index) {
            onReorder!(fromIndex, index);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          
          return Stack(
            children: [
              // 原始内容
              LongPressDraggable<int>(
                data: index,
                feedback: Material(
                  color: Colors.transparent,
                  child: Opacity(
                    opacity: 0.7,
                    child: Container(
                      width: 360,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFFF4D7D),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Image.memory(
                        imageData!,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: cellContent,
                ),
                onDragStarted: () {
                  // 拖拽开始时的反馈
                },
                child: GestureDetector(
                  onTap: onTap,
                  behavior: HitTestBehavior.opaque,
                  child: cellContent,
                ),
              ),
              
              // 🔥 悬停指示器
              if (isHovering)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D7D).withOpacity(0.3),
                      border: Border.all(
                        color: const Color(0xFFFF4D7D),
                        width: 3,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.swap_vert,
                        size: 40,
                        color: Color(0xFFFF4D7D),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }

    // 没有拖拽功能时的普通显示
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: cellContent,
    );
  }
}
