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
      default:
        return [];
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
    
    // 计算行列数
    int maxRows = 0;
    int maxCols = 0;
    for (final block in template.blocks) {
      if (block.row > maxRows) maxRows = block.row;
      if (block.col > maxCols) maxCols = block.col;
    }
    maxRows += 1;
    maxCols += 1;

    // 计算单个块的宽高（相对值）
    final totalSpacingX = spacing * (maxCols - 1);
    final totalSpacingY = spacing * (maxRows - 1);
    final blockWidth = (1.0 - totalSpacingX) / maxCols;
    final blockHeight = (1.0 - totalSpacingY) / maxRows;

    // 为每个图片创建块
    for (int i = 0; i < imageCount; i++) {
      final block = template.blocks[i];
      final x = block.col * (blockWidth + spacing);
      final y = block.row * (blockHeight + spacing);

      blocks.add(ImageBlock(
        id: 'block_$i',
        layoutBlockId: '${template.id}_$i',
        x: x,
        y: y,
        width: blockWidth,
        height: blockHeight,
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
    final isVertical = canvas.isVertical; // 竖版画布

    // 找出主图（权重最大的块）
    final sortedBlocks = List<LayoutBlock>.from(template.blocks)
      ..sort((a, b) => b.weight.compareTo(a.weight));
    
    final mainBlock = sortedBlocks.first;
    final secondaryBlocks = sortedBlocks.skip(1).take(imageCount - 1).toList();

    if (isVertical) {
      // 竖版：上下分布（主图占上，小图占下）
      final mainHeight = mainBlock.weight - spacing;
      final secondaryHeight = (1.0 - mainBlock.weight - spacing);
      
      // 主图
      blocks.add(ImageBlock(
        id: 'block_0',
        layoutBlockId: '${template.id}_0',
        x: 0,
        y: 0,
        width: 1.0,
        height: mainHeight,
        imageData: images[0],
        zIndex: 0,
      ));

      // 小图横向排列
      final secondaryCount = secondaryBlocks.length;
      final totalSpacing = spacing * (secondaryCount - 1);
      final secondaryWidth = (1.0 - totalSpacing) / secondaryCount;
      
      for (int i = 0; i < secondaryCount && i + 1 < imageCount; i++) {
        blocks.add(ImageBlock(
          id: 'block_${i + 1}',
          layoutBlockId: '${template.id}_${i + 1}',
          x: i * (secondaryWidth + spacing),
          y: mainHeight + spacing * 2,
          width: secondaryWidth,
          height: secondaryHeight,
          imageData: images[i + 1],
          zIndex: i + 1,
        ));
      }
    } else {
      // 横版：左右分布（主图占左，小图占右）
      final mainWidth = mainBlock.weight - spacing;
      final secondaryWidth = (1.0 - mainBlock.weight - spacing);
      
      // 主图
      blocks.add(ImageBlock(
        id: 'block_0',
        layoutBlockId: '${template.id}_0',
        x: 0,
        y: 0,
        width: mainWidth,
        height: 1.0,
        imageData: images[0],
        zIndex: 0,
      ));

      // 小图纵向排列
      final secondaryCount = secondaryBlocks.length;
      final totalSpacing = spacing * (secondaryCount - 1);
      final secondaryHeight = (1.0 - totalSpacing) / secondaryCount;
      
      for (int i = 0; i < secondaryCount && i + 1 < imageCount; i++) {
        blocks.add(ImageBlock(
          id: 'block_${i + 1}',
          layoutBlockId: '${template.id}_${i + 1}',
          x: mainWidth + spacing * 2,
          y: i * (secondaryHeight + spacing),
          width: secondaryWidth,
          height: secondaryHeight,
          imageData: images[i + 1],
          zIndex: i + 1,
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
