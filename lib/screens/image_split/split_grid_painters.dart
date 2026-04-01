import 'package:flutter/material.dart';

/// 切割线网格覆盖层
class SplitGridPainter extends CustomPainter {
  final int rows;
  final int cols;
  SplitGridPainter({required this.rows, required this.cols});

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int c = 1; c < cols; c++) {
      final x = size.width * c / cols;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), shadow);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (int r = 1; r < rows; r++) {
      final y = size.height * r / rows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), shadow);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(SplitGridPainter old) =>
      old.rows != rows || old.cols != cols;
}

/// 模式选择器中的缩略网格图标
class MiniGridPainter extends CustomPainter {
  final int rows;
  final int cols;
  final Color color;
  MiniGridPainter({
    required this.rows,
    required this.cols,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(3),
      ),
      paint,
    );
    for (int c = 1; c < cols; c++) {
      final x = size.width * c / cols;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (int r = 1; r < rows; r++) {
      final y = size.height * r / rows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(MiniGridPainter old) =>
      old.rows != rows || old.cols != cols || old.color != color;
}
