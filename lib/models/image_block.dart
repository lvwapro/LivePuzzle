import 'dart:typed_data';

/// 图片块实例（关联布局+图片，使用相对值 0-1）
class ImageBlock {
  final String id;              // 图片唯一标识
  final String layoutBlockId;   // 关联的布局块ID
  final double x;               // 画布内x坐标（相对值 0-1）
  final double y;               // 画布内y坐标（相对值 0-1）
  final double width;           // 块宽度（相对值 0-1）
  final double height;          // 块高度（相对值 0-1）
  final Uint8List? imageData;   // 图片数据
  final double rotate;          // 旋转角度（弧度）
  final double scale;           // 缩放比例（1.0=原始，>1放大）
  final double offsetX;         // 图片在框内的水平偏移（画布像素）
  final double offsetY;         // 图片在框内的垂直偏移（画布像素）
  final double imageAspectRatio; // 原图宽高比（width/height），0表示未知
  final int zIndex;             // 层级

  const ImageBlock({
    required this.id,
    required this.layoutBlockId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.imageData,
    this.rotate = 0.0,
    this.scale = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.imageAspectRatio = 0.0,
    this.zIndex = 0,
  });

  /// 转换为绝对像素坐标（用于渲染）
  ImageBlockAbsolute toAbsolute(double canvasWidth, double canvasHeight) {
    return ImageBlockAbsolute(
      id: id,
      layoutBlockId: layoutBlockId,
      x: x * canvasWidth,
      y: y * canvasHeight,
      width: width * canvasWidth,
      height: height * canvasHeight,
      imageData: imageData,
      rotate: rotate,
      scale: scale,
      offsetX: offsetX,
      offsetY: offsetY,
      imageAspectRatio: imageAspectRatio,
      zIndex: zIndex,
    );
  }

  ImageBlock copyWith({
    String? id,
    String? layoutBlockId,
    double? x,
    double? y,
    double? width,
    double? height,
    Uint8List? imageData,
    double? rotate,
    double? scale,
    double? offsetX,
    double? offsetY,
    double? imageAspectRatio,
    int? zIndex,
  }) {
    return ImageBlock(
      id: id ?? this.id,
      layoutBlockId: layoutBlockId ?? this.layoutBlockId,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      imageData: imageData ?? this.imageData,
      rotate: rotate ?? this.rotate,
      scale: scale ?? this.scale,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      imageAspectRatio: imageAspectRatio ?? this.imageAspectRatio,
      zIndex: zIndex ?? this.zIndex,
    );
  }
}

/// 图片块绝对坐标（用于渲染）
class ImageBlockAbsolute {
  final String id;
  final String layoutBlockId;
  final double x;
  final double y;
  final double width;
  final double height;
  final Uint8List? imageData;
  final double rotate;
  final double scale;
  final double offsetX;
  final double offsetY;
  final double imageAspectRatio;
  final int zIndex;

  const ImageBlockAbsolute({
    required this.id,
    required this.layoutBlockId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.imageData,
    this.rotate = 0.0,
    this.scale = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.imageAspectRatio = 0.0,
    this.zIndex = 0,
  });
}
