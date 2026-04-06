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

    Widget imageContent;
    if ((useVideo || abs.imageData != null) && contentAR > 0) {
      final frameAR = abs.width / abs.height;
      double coverW, coverH;
      if (contentAR > frameAR) {
        coverH = abs.height;
        coverW = abs.height * contentAR;
      } else {
        coverW = abs.width;
        coverH = abs.width / contentAR;
      }
      coverW *= block.scale;
      coverH *= block.scale;

      final left = (abs.width - coverW) / 2 + previewOx;
      final top = (abs.height - coverH) / 2 + previewOy;

      // 视频渲染：缩略图打底 + FittedBox.cover 确保视频填满，
      // 避免 VideoPlayer 默认 letterbox 模式在帧编辑时露出黑边
      final Widget child;
      if (useVideo) {
        final vs = videoController!.value.size;
        child = Stack(
          fit: StackFit.expand,
          children: [
            if (abs.imageData != null)
              Image.memory(
                abs.imageData!,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                filterQuality: FilterQuality.high,
              ),
            if (vs.width > 0 && vs.height > 0)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: vs.width,
                  height: vs.height,
                  child: VideoPlayer(videoController!),
                ),
              ),
          ],
        );
      } else {
        child = Image.memory(
          abs.imageData!,
          fit: BoxFit.fill,
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
        );
      }

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
                child: child,
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

    final br = cornerRadius > 0 ? BorderRadius.circular(cornerRadius) : null;

    final clipped = br != null
        ? ClipRRect(borderRadius: br, child: imageContent)
        : imageContent;

    // 边框用 Stack 叠加，不影响图片尺寸
    Widget content;
    BoxDecoration? borderDeco;
    if (isMoving && !withinBounds) {
      borderDeco = BoxDecoration(
        borderRadius: br,
        border: Border.all(color: const Color(0xFF4FC3F7), width: 3),
      );
    } else if (selected) {
      borderDeco = BoxDecoration(
        borderRadius: br,
        border: Border.all(
          color: const Color(0xFFFF85A2).withValues(alpha: 0.7),
          width: 2,
        ),
      );
    }

    if (borderDeco != null) {
      content = SizedBox(
        width: abs.width,
        height: abs.height,
        child: Stack(
          children: [
            Positioned.fill(child: clipped),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(decoration: borderDeco),
              ),
            ),
          ],
        ),
      );
    } else {
      content = SizedBox(
        width: abs.width,
        height: abs.height,
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
