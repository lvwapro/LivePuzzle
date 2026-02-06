import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:live_puzzle/models/puzzle_project.dart';
import 'package:live_puzzle/utils/file_helpers.dart';

/// 拼图生成器
/// 负责将多个帧组合成拼图图片
class PuzzleGenerator {
  /// 生成拼图图片
  static Future<File?> generatePuzzleImage(
    PuzzleProject project, {
    int outputWidth = 1080,
    int outputHeight = 1080,
  }) async {
    try {
      // 创建空白画布
      final canvas = img.Image(
        width: outputWidth,
        height: outputHeight,
      );

      // 填充背景色
      if (project.layout.backgroundColor != null) {
        final bgColor = project.layout.backgroundColor!;
        final color = img.ColorRgb8(
          (bgColor.red * 255).toInt(),
          (bgColor.green * 255).toInt(),
          (bgColor.blue * 255).toInt(),
        );
        img.fill(canvas, color: color);
      } else {
        // 默认白色背景
        img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
      }

      // 绘制每个单元格
      for (int i = 0; i < project.frames.length; i++) {
        final frame = project.frames[i];
        final cell = project.layout.cells[frame.positionInPuzzle];

        // 解码帧图片
        final frameImage = img.decodeImage(frame.frameData.imageData);
        if (frameImage == null) continue;

        // 计算单元格在画布上的实际位置和大小
        final cellX = (cell.rect.left * outputWidth).toInt();
        final cellY = (cell.rect.top * outputHeight).toInt();
        final cellWidth = (cell.rect.width * outputWidth).toInt();
        final cellHeight = (cell.rect.height * outputHeight).toInt();

        // 调整间距
        final spacing = project.layout.spacing.toInt();
        final adjustedX = cellX + spacing ~/ 2;
        final adjustedY = cellY + spacing ~/ 2;
        final adjustedWidth = (cellWidth - spacing).clamp(1, outputWidth);
        final adjustedHeight = (cellHeight - spacing).clamp(1, outputHeight);

        // 缩放图片以适应单元格
        final resizedImage = img.copyResize(
          frameImage,
          width: adjustedWidth,
          height: adjustedHeight,
          interpolation: img.Interpolation.linear,
        );

        // 应用旋转
        img.Image rotatedImage = resizedImage;
        if (cell.rotation != 0) {
          final angleDegrees = cell.rotation * 180 / 3.14159;
          rotatedImage = img.copyRotate(
            resizedImage,
            angle: angleDegrees,
          );
        }

        // 应用自定义缩放
        if (cell.customScale != null && cell.customScale != 1.0) {
          final scaledWidth = (adjustedWidth * cell.customScale!).toInt();
          final scaledHeight = (adjustedHeight * cell.customScale!).toInt();
          rotatedImage = img.copyResize(
            rotatedImage,
            width: scaledWidth.clamp(1, outputWidth),
            height: scaledHeight.clamp(1, outputHeight),
          );
        }

        // 合成到画布上
        img.compositeImage(
          canvas,
          rotatedImage,
          dstX: adjustedX.clamp(0, outputWidth),
          dstY: adjustedY.clamp(0, outputHeight),
        );
      }

      // 保存到文件
      final outputPath = await FileHelper.createTempFilePath('jpg');
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(img.encodeJpg(canvas, quality: 95));

      return outputFile;
    } catch (e, stack) {
      print('生成拼图图片时出错: $e');
      print(stack);
      return null;
    }
  }

  /// 生成预览缩略图
  static Future<Uint8List?> generatePreviewThumbnail(
    PuzzleProject project, {
    int size = 300,
  }) async {
    try {
      final file = await generatePuzzleImage(
        project,
        outputWidth: size,
        outputHeight: size,
      );

      if (file == null) return null;

      final bytes = await file.readAsBytes();
      await file.delete(); // 删除临时文件

      return bytes;
    } catch (e) {
      print('生成预览缩略图时出错: $e');
      return null;
    }
  }
}
