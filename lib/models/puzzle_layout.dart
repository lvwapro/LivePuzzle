import 'package:flutter/material.dart';

/// 拼图布局类型
enum LayoutType {
  grid2x2,
  grid3x3,
  grid2x3,
  collageHorizontal,
  collageVertical,
  freeForm,
}

/// 拼图布局模型
class PuzzleLayout {
  final LayoutType type;
  final List<PuzzleCell> cells;
  final double spacing;
  final Color? backgroundColor;
  final double borderRadius;

  const PuzzleLayout({
    required this.type,
    required this.cells,
    this.spacing = 4.0,
    this.backgroundColor,
    this.borderRadius = 0.0,
  });

  PuzzleLayout copyWith({
    LayoutType? type,
    List<PuzzleCell>? cells,
    double? spacing,
    Color? backgroundColor,
    double? borderRadius,
  }) {
    return PuzzleLayout(
      type: type ?? this.type,
      cells: cells ?? this.cells,
      spacing: spacing ?? this.spacing,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  factory PuzzleLayout.grid2x2() {
    return PuzzleLayout(
      type: LayoutType.grid2x2,
      cells: [
        const PuzzleCell(rect: Rect.fromLTWH(0, 0, 0.5, 0.5)),
        const PuzzleCell(rect: Rect.fromLTWH(0.5, 0, 0.5, 0.5)),
        const PuzzleCell(rect: Rect.fromLTWH(0, 0.5, 0.5, 0.5)),
        const PuzzleCell(rect: Rect.fromLTWH(0.5, 0.5, 0.5, 0.5)),
      ],
    );
  }

  factory PuzzleLayout.grid3x3() {
    return PuzzleLayout(
      type: LayoutType.grid3x3,
      cells: List.generate(9, (i) {
        final row = i ~/ 3;
        final col = i % 3;
        return PuzzleCell(
          rect: Rect.fromLTWH(
            col / 3.0,
            row / 3.0,
            1 / 3.0,
            1 / 3.0,
          ),
        );
      }),
    );
  }

  factory PuzzleLayout.grid2x3() {
    return PuzzleLayout(
      type: LayoutType.grid2x3,
      cells: List.generate(6, (i) {
        final row = i ~/ 3;
        final col = i % 3;
        return PuzzleCell(
          rect: Rect.fromLTWH(
            col / 3.0,
            row / 2.0,
            1 / 3.0,
            1 / 2.0,
          ),
        );
      }),
    );
  }
}

/// 拼图单元格
class PuzzleCell {
  final Rect rect; // 相对位置和大小（0-1范围）
  final double rotation; // 旋转角度（弧度）
  final Offset? customOffset; // 自定义偏移
  final double? customScale; // 自定义缩放

  const PuzzleCell({
    required this.rect,
    this.rotation = 0.0,
    this.customOffset,
    this.customScale,
  });

  PuzzleCell copyWith({
    Rect? rect,
    double? rotation,
    Offset? customOffset,
    double? customScale,
  }) {
    return PuzzleCell(
      rect: rect ?? this.rect,
      rotation: rotation ?? this.rotation,
      customOffset: customOffset ?? this.customOffset,
      customScale: customScale ?? this.customScale,
    );
  }
}
