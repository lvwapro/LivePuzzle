import 'package:flutter/material.dart';
import '../../models/image_block.dart';

/// 计算 cover 模式下图片溢出量
(double, double) calcCoverOverflow(ImageBlockAbsolute abs) {
  final imgAR = abs.imageAspectRatio;
  if (imgAR <= 0) return (0, 0);
  final frameAR = abs.width / abs.height;
  if (imgAR > frameAR) {
    final coverW = abs.height * imgAR;
    return ((coverW - abs.width) / 2, 0);
  } else {
    final coverH = abs.width / imgAR;
    return (0, (coverH - abs.height) / 2);
  }
}

class CanvasImageBlockWidget extends StatelessWidget {
  final ImageBlock block;
  final ImageBlockAbsolute abs;
  final bool selected;
  final bool isMoving;
  final bool withinBounds;
  final double moveDeltaX;
  final double moveDeltaY;
  final bool hasMoved;
  final bool isMovingImage;
  final void Function(String blockId) onBlockTap;

  const CanvasImageBlockWidget({
    super.key,
    required this.block,
    required this.abs,
    required this.selected,
    required this.isMoving,
    required this.withinBounds,
    required this.moveDeltaX,
    required this.moveDeltaY,
    required this.hasMoved,
    required this.isMovingImage,
    required this.onBlockTap,
  });

  @override
  Widget build(BuildContext context) {
    final (overflowX, overflowY) = calcCoverOverflow(abs);
    final maxOx =
        overflowX * block.scale + abs.width * (block.scale - 1) / 2;
    final maxOy =
        overflowY * block.scale + abs.height * (block.scale - 1) / 2;

    double previewOx = block.offsetX;
    double previewOy = block.offsetY;
    if (isMoving && withinBounds) {
      previewOx = (block.offsetX + moveDeltaX).clamp(-maxOx, maxOx);
      previewOy = (block.offsetY + moveDeltaY).clamp(-maxOy, maxOy);
    }

    Widget imageContent;
    if (abs.imageData != null && abs.imageAspectRatio > 0) {
      final frameAR = abs.width / abs.height;
      final imgAR = abs.imageAspectRatio;
      double coverW, coverH;
      if (imgAR > frameAR) {
        coverH = abs.height;
        coverW = abs.height * imgAR;
      } else {
        coverW = abs.width;
        coverH = abs.width / imgAR;
      }
      coverW *= block.scale;
      coverH *= block.scale;

      final left = (abs.width - coverW) / 2 + previewOx;
      final top = (abs.height - coverH) / 2 + previewOy;

      imageContent = SizedBox(
        width: abs.width,
        height: abs.height,
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: left,
                top: top,
                width: coverW,
                height: coverH,
                child: Image.memory(
                  abs.imageData!,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      imageContent = SizedBox(
        width: abs.width,
        height: abs.height,
        child: abs.imageData != null
            ? Image.memory(
                abs.imageData!,
                fit: BoxFit.cover,
                width: abs.width,
                height: abs.height,
                gaplessPlayback: true,
                filterQuality: FilterQuality.high,
              )
            : const Center(child: Icon(Icons.image, color: Colors.grey)),
      );
    }

    BoxDecoration? deco;
    if (isMoving && !withinBounds) {
      deco = BoxDecoration(
        border: Border.all(color: const Color(0xFF4FC3F7), width: 4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4FC3F7).withValues(alpha: 0.5),
            blurRadius: 16,
            spreadRadius: 4,
          ),
        ],
      );
    } else if (selected) {
      deco = BoxDecoration(
        border: Border.all(color: const Color(0xFFFF85A2), width: 5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF85A2).withValues(alpha: 0.4),
            blurRadius: 14,
            spreadRadius: 3,
          ),
        ],
      );
    }

    Widget content = Container(
      width: abs.width,
      height: abs.height,
      decoration: deco,
      child: imageContent,
    );

    final posX = abs.x + (isMoving && !withinBounds ? moveDeltaX : 0);
    final posY = abs.y + (isMoving && !withinBounds ? moveDeltaY : 0);

    return Positioned(
      left: posX,
      top: posY,
      child: GestureDetector(
        onTap: () {
          if (!hasMoved && !isMovingImage) {
            onBlockTap(block.id);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: isMoving && !withinBounds ? 0.8 : 1.0,
          child: content,
        ),
      ),
    );
  }
}
