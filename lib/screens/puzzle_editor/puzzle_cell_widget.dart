import 'dart:typed_data';
import 'package:flutter/material.dart';

/// 拼图单元格组件
class PuzzleCell extends StatelessWidget {
  final int index;
  final Uint8List? imageData;
  final bool isSelected;
  final VoidCallback onTap;

  const PuzzleCell({
    super.key,
    required this.index,
    required this.imageData,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F5),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF4D7D)
                : Colors.transparent,
            width: isSelected ? 3 : 0,
          ),
        ),
        child: imageData != null
            ? Image.memory(
                imageData!,
                fit: BoxFit.contain,
                width: double.infinity,
                gaplessPlayback: true, // 🔥 避免图片切换时的闪烁
                // 🔥 移除 cacheWidth 限制，保持原始清晰度
                filterQuality: FilterQuality.high, // 使用高质量过滤
              )
            : const SizedBox(
                height: 200,
                child: Center(
                  child: Icon(
                    Icons.add_photo_alternate,
                    size: 40,
                    color: Colors.grey,
                  ),
                ),
              ),
      ),
    );
  }
}
