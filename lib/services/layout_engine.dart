import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/canvas_config.dart';
import '../models/layout_template.dart';
import '../models/image_block.dart';

/// 布局计算引擎（核心算法）
class LayoutEngine {
  /// 根据画布配置、布局模板和图片列表，计算所有图片块的位置
  static List<ImageBlock> calculateLayout({
    required CanvasConfig canvas,
    required LayoutTemplate template,
    required List<Uint8List> images,
    double spacing = 0.0, // 🔥 相对间距（相对画布宽度，默认无间距）
  }) {
    if (images.isEmpty || template.blocks.isEmpty) {
      return [];
    }

    final imageCount = math.min(images.length, template.blocks.length);
    
    switch (template.type) {
      case LayoutTemplateType.grid:
        return _calculateGridLayout(canvas, template, images, imageCount, spacing);
      case LayoutTemplateType.hierarchy:
        return _calculateHierarchyLayout(canvas, template, images, imageCount, spacing);
      case LayoutTemplateType.column:
        return _calculateColumnLayout(canvas, template, images, imageCount, spacing);
      case LayoutTemplateType.free:
        return _calculateFreeLayout(canvas, template, images, imageCount);
      case LayoutTemplateType.positioned:
        return _calculatePositionedLayout(canvas, template, images, imageCount, spacing);
    }
  }

  /// 网格型布局计算
  static List<ImageBlock> _calculateGridLayout(
    CanvasConfig canvas,
    LayoutTemplate template,
    List<Uint8List> images,
    int imageCount,
    double spacing,
  ) {
    final blocks = <ImageBlock>[];
    
    int maxRows = 0;
    int maxCols = 0;
    for (final block in template.blocks) {
      if (block.row > maxRows) maxRows = block.row;
      if (block.col > maxCols) maxCols = block.col;
    }
    maxRows += 1;
    maxCols += 1;

    final totalSpacingX = spacing * (maxCols - 1);
    final totalSpacingY = spacing * (maxRows - 1);
    final blockWidth = (1.0 - totalSpacingX) / maxCols;
    final blockHeight = (1.0 - totalSpacingY) / maxRows;

    for (int i = 0; i < imageCount; i++) {
      final block = template.blocks[i];
      final x = block.col * (blockWidth + spacing);
      final y = block.row * (blockHeight + spacing);

      // 最后一列/行用 1.0 - pos 确保精确到边
      final w = block.col == maxCols - 1 ? 1.0 - x : blockWidth;
      final h = block.row == maxRows - 1 ? 1.0 - y : blockHeight;

      blocks.add(ImageBlock(
        id: 'block_$i',
        layoutBlockId: '${template.id}_$i',
        x: x,
        y: y,
        width: w,
        height: h,
        imageData: images[i],
        zIndex: i,
      ));
    }

    return blocks;
  }

  /// 主次型布局计算
  static List<ImageBlock> _calculateHierarchyLayout(
    CanvasConfig canvas,
    LayoutTemplate template,
    List<Uint8List> images,
    int imageCount,
    double spacing,
  ) {
    final blocks = <ImageBlock>[];
    final isVertical = canvas.isVertical;

    final sortedBlocks = List<LayoutBlock>.from(template.blocks)
      ..sort((a, b) => b.weight.compareTo(a.weight));
    
    final mainBlock = sortedBlocks.first;
    final secondaryBlocks = sortedBlocks.skip(1).take(imageCount - 1).toList();

    if (isVertical) {
      final mainHeight = mainBlock.weight - spacing;
      final secondaryY = mainHeight + spacing * 2;
      final secondaryHeight = 1.0 - secondaryY;
      
      blocks.add(ImageBlock(
        id: 'block_0',
        layoutBlockId: '${template.id}_0',
        x: 0, y: 0,
        width: 1.0, height: mainHeight,
        imageData: images[0], zIndex: 0,
      ));

      final secondaryCount = secondaryBlocks.length;
      final totalSpacing = spacing * (secondaryCount - 1);
      final secondaryWidth = (1.0 - totalSpacing) / secondaryCount;
      
      for (int i = 0; i < secondaryCount && i + 1 < imageCount; i++) {
        final x = i * (secondaryWidth + spacing);
        final isLast = i == secondaryCount - 1;
        blocks.add(ImageBlock(
          id: 'block_${i + 1}',
          layoutBlockId: '${template.id}_${i + 1}',
          x: x, y: secondaryY,
          width: isLast ? 1.0 - x : secondaryWidth,
          height: secondaryHeight,
          imageData: images[i + 1], zIndex: i + 1,
        ));
      }
    } else {
      final mainWidth = mainBlock.weight - spacing;
      final secondaryX = mainWidth + spacing * 2;
      final secondaryWidth = 1.0 - secondaryX;
      
      blocks.add(ImageBlock(
        id: 'block_0',
        layoutBlockId: '${template.id}_0',
        x: 0, y: 0,
        width: mainWidth, height: 1.0,
        imageData: images[0], zIndex: 0,
      ));

      final secondaryCount = secondaryBlocks.length;
      final totalSpacing = spacing * (secondaryCount - 1);
      final secondaryHeight = (1.0 - totalSpacing) / secondaryCount;
      
      for (int i = 0; i < secondaryCount && i + 1 < imageCount; i++) {
        final y = i * (secondaryHeight + spacing);
        final isLast = i == secondaryCount - 1;
        blocks.add(ImageBlock(
          id: 'block_${i + 1}',
          layoutBlockId: '${template.id}_${i + 1}',
          x: secondaryX, y: y,
          width: secondaryWidth,
          height: isLast ? 1.0 - y : secondaryHeight,
          imageData: images[i + 1], zIndex: i + 1,
        ));
      }
    }

    return blocks;
  }

  /// 分栏型布局计算（暂时简化为网格）
  static List<ImageBlock> _calculateColumnLayout(
    CanvasConfig canvas,
    LayoutTemplate template,
    List<Uint8List> images,
    int imageCount,
    double spacing,
  ) {
    // TODO: 实现更复杂的分栏逻辑
    return _calculateGridLayout(canvas, template, images, imageCount, spacing);
  }

  /// 自定义定位布局：使用 LayoutBlock 中的显式坐标，按边缘检测应用间距
  static List<ImageBlock> _calculatePositionedLayout(
    CanvasConfig canvas,
    LayoutTemplate template,
    List<Uint8List> images,
    int imageCount,
    double spacing,
  ) {
    final half = spacing / 2.0;
    final blocks = <ImageBlock>[];

    for (int i = 0; i < imageCount; i++) {
      final lb = template.blocks[i];
      final bx = lb.relX ?? 0;
      final by = lb.relY ?? 0;
      final bw = lb.relWidth ?? 0.5;
      final bh = lb.relHeight ?? 0.5;

      final leftPad = bx > 0.001 ? half : 0.0;
      final topPad = by > 0.001 ? half : 0.0;
      final rightPad = (bx + bw) < 0.999 ? half : 0.0;
      final bottomPad = (by + bh) < 0.999 ? half : 0.0;

      blocks.add(ImageBlock(
        id: 'block_$i',
        layoutBlockId: '${template.id}_$i',
        x: bx + leftPad,
        y: by + topPad,
        width: bw - leftPad - rightPad,
        height: bh - topPad - bottomPad,
        imageData: images[i],
        zIndex: i,
      ));
    }
    return blocks;
  }

  /// 自由型布局计算（保持用户自定义位置）
  static List<ImageBlock> _calculateFreeLayout(
    CanvasConfig canvas,
    LayoutTemplate template,
    List<Uint8List> images,
    int imageCount,
  ) {
    final blocks = <ImageBlock>[];
    
    // 自由布局直接使用模板中定义的权重作为位置
    for (int i = 0; i < imageCount; i++) {
      final block = template.blocks[i];
      blocks.add(ImageBlock(
        id: 'block_$i',
        layoutBlockId: '${template.id}_$i',
        x: block.weight, // 暂时用weight表示x
        y: block.weight, // 暂时用weight表示y
        width: 0.3, // 默认宽度
        height: 0.3, // 默认高度
        imageData: images[i],
        zIndex: i,
      ));
    }

    return blocks;
  }

}
