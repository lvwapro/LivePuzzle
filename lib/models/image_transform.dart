import 'package:flutter/material.dart';

/// 图片变换数据模型
class ImageTransform {
  Offset position;      // 位置
  double scale;         // 缩放（1.0 为原始大小）
  double rotation;      // 旋转角度（弧度）
  int zIndex;           // 层级（用于置顶/置底）
  double aspectRatio;   // 🔥 宽高比（宽/高）

  ImageTransform({
    this.position = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.zIndex = 0,
    this.aspectRatio = 1.0, // 默认1:1
  });

  ImageTransform copyWith({
    Offset? position,
    double? scale,
    double? rotation,
    int? zIndex,
    double? aspectRatio,
  }) {
    return ImageTransform(
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      zIndex: zIndex ?? this.zIndex,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }
}
