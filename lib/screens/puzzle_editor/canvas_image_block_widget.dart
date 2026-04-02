import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
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
  final VideoPlayerController? videoController;
  final double cornerRadius;

  const CanvasImageBlockWidget({
    super.key,
    required this.block,
    required this.abs,
    required this.selected,
    required this.isMoving,
    required this.withinBounds,
    required this.moveDeltaX,
    required this.moveDeltaY,
    this.videoController,
    this.cornerRadius = 0.0,
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

    final useVideo =
        videoController != null && videoController!.value.isInitialized;

    final double contentAR;
    if (useVideo) {
      final vs = videoController!.value.size;
      contentAR = (vs.width > 0 && vs.height > 0) ? vs.width / vs.height : 1.0;
    } else {
      contentAR = abs.imageAspectRatio;
    }

    // 延伸 1px 消除相邻块反锯齿间隙（Stack 的 Clip.hardEdge 裁剪溢出）
    final renderW = abs.width + 1.0;
    final renderH = abs.height + 1.0;

    Widget imageContent;
    if ((useVideo || abs.imageData != null) && contentAR > 0) {
      final frameAR = renderW / renderH;
      double coverW, coverH;
      if (contentAR > frameAR) {
        coverH = renderH;
        coverW = renderH * contentAR;
      } else {
        coverW = renderW;
        coverH = renderW / contentAR;
      }
      coverW *= block.scale * 1.002;
      coverH *= block.scale * 1.002;

      final left = (renderW - coverW) / 2 + previewOx;
      final top = (renderH - coverH) / 2 + previewOy;

      final Widget child = useVideo
          ? VideoPlayer(videoController!)
          : Image.memory(
              abs.imageData!,
              fit: BoxFit.fill,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
            );

      imageContent = SizedBox(
        width: renderW,
        height: renderH,
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: left,
                top: top,
                width: coverW,
                height: coverH,
                child: child,
              ),
            ],
          ),
        ),
      );
    } else {
      imageContent = SizedBox(
        width: renderW,
        height: renderH,
        child: abs.imageData != null
            ? Image.memory(
                abs.imageData!,
                fit: BoxFit.cover,
                width: renderW,
                height: renderH,
                gaplessPlayback: true,
                filterQuality: FilterQuality.high,
              )
            : const Center(child: Icon(Icons.image, color: Colors.grey)),
      );
    }

    final br = cornerRadius > 0 ? BorderRadius.circular(cornerRadius) : null;

    final clipped = br != null
        ? ClipRRect(borderRadius: br, child: imageContent)
        : imageContent;

    // 选中/拖动边框用 Stack 叠加，避免 Container decoration border 内缩子视图
    Widget content;
    if (isMoving && !withinBounds) {
      content = SizedBox(
        width: renderW,
        height: renderH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: clipped),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: br,
                  border: Border.all(color: const Color(0xFF4FC3F7), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4FC3F7).withValues(alpha: 0.5),
                      blurRadius: 16, spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else if (selected) {
      content = SizedBox(
        width: renderW,
        height: renderH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: clipped),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: br,
                  border: Border.all(color: const Color(0xFFFF85A2), width: 5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF85A2).withValues(alpha: 0.4),
                      blurRadius: 14, spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      content = SizedBox(
        width: renderW,
        height: renderH,
        child: clipped,
      );
    }

    final posX = abs.x + (isMoving && !withinBounds ? moveDeltaX : 0);
    final posY = abs.y + (isMoving && !withinBounds ? moveDeltaY : 0);

    return Positioned(
      left: posX,
      top: posY,
      child: Opacity(
        opacity: isMoving && !withinBounds ? 0.8 : 1.0,
        child: content,
      ),
    );
  }
}
