import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/painting.dart';

/// 图片切割服务 - 支持裁剪比例 + 网格切割
class ImageSplitService {
  /// 切割图片
  /// [imageData] 原始图片数据
  /// [rows] / [cols] 切割网格
  /// [cropRatio] 裁剪比例（null = 原图比例）
  /// [alignX] / [alignY] 裁剪对齐 [-1, 1]（0 = 居中）
  static Future<List<Uint8List>> splitImage({
    required Uint8List imageData,
    required int rows,
    required int cols,
    double? cropRatio,
    double alignX = 0,
    double alignY = 0,
  }) async {
    final codec = await ui.instantiateImageCodec(imageData);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();

    double srcX = 0, srcY = 0, srcW = imgW, srcH = imgH;

    if (cropRatio != null) {
      final imgAspect = imgW / imgH;
      if (imgAspect > cropRatio) {
        srcW = imgH * cropRatio;
        srcX = (imgW - srcW) * (alignX + 1) / 2;
      } else if (imgAspect < cropRatio) {
        srcH = imgW / cropRatio;
        srcY = (imgH - srcH) * (alignY + 1) / 2;
      }
    }

    final pieceW = srcW / cols;
    final pieceH = srcH / rows;
    final results = <Uint8List>[];

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final srcRect = Rect.fromLTWH(
          srcX + c * pieceW,
          srcY + r * pieceH,
          pieceW,
          pieceH,
        );

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, pieceW, pieceH));
        canvas.drawImageRect(
          image,
          srcRect,
          Rect.fromLTWH(0, 0, pieceW, pieceH),
          Paint()..filterQuality = FilterQuality.high,
        );

        final picture = recorder.endRecording();
        final pieceImage =
            await picture.toImage(pieceW.round(), pieceH.round());
        final byteData =
            await pieceImage.toByteData(format: ui.ImageByteFormat.png);
        pieceImage.dispose();

        if (byteData != null) {
          results.add(byteData.buffer.asUint8List());
        }
      }
    }

    image.dispose();
    return results;
  }
}
