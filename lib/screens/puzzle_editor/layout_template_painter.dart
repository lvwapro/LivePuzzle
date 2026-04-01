import 'package:flutter/material.dart';
import '../../models/layout_template.dart';

/// 布局模板绘制器（基于LayoutTemplate绘制预览）
class LayoutTemplatePainter extends CustomPainter {
  final LayoutTemplate template;
  final Color color;

  LayoutTemplatePainter({
    required this.template,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padding = 4.0;
    final drawArea = Size(size.width - padding * 2, size.height - padding * 2);

    switch (template.type) {
      case LayoutTemplateType.grid:
        _drawGrid(canvas, drawArea, padding);
        break;
      case LayoutTemplateType.hierarchy:
        _drawHierarchy(canvas, drawArea, padding);
        break;
      default:
        _drawGrid(canvas, drawArea, padding);
    }
  }

  void _drawGrid(Canvas canvas, Size drawArea, double padding) {
    int maxRows = 0;
    int maxCols = 0;
    for (final block in template.blocks) {
      if (block.row > maxRows) maxRows = block.row;
      if (block.col > maxCols) maxCols = block.col;
    }
    maxRows += 1;
    maxCols += 1;

    const spacing = 3.0;
    final cellWidth = (drawArea.width - spacing * (maxCols - 1)) / maxCols;
    final cellHeight = (drawArea.height - spacing * (maxRows - 1)) / maxRows;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final block in template.blocks) {
      final rect = Rect.fromLTWH(
        padding + block.col * (cellWidth + spacing),
        padding + block.row * (cellHeight + spacing),
        cellWidth,
        cellHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        fillPaint,
      );
    }
  }

  void _drawHierarchy(Canvas canvas, Size drawArea, double padding) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const spacing = 3.0;

    final mainRect = Rect.fromLTWH(
      padding,
      padding,
      drawArea.width,
      drawArea.height * 0.6 - spacing / 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(mainRect, const Radius.circular(3)),
      fillPaint,
    );

    final secondaryCount = template.blocks.length - 1;
    if (secondaryCount <= 0) return;
    final secondaryWidth =
        (drawArea.width - spacing * (secondaryCount - 1)) / secondaryCount;
    final secondaryTop = padding + drawArea.height * 0.6 + spacing / 2;
    final secondaryHeight = drawArea.height * 0.4 - spacing / 2;
    for (int i = 0; i < secondaryCount; i++) {
      final rect = Rect.fromLTWH(
        padding + i * (secondaryWidth + spacing),
        secondaryTop,
        secondaryWidth,
        secondaryHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
