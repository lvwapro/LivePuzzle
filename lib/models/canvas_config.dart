/// 画布配置数据模型
class CanvasConfig {
  final double width;       // 画布像素宽
  final double height;      // 画布像素高
  final String ratio;       // 画布比例（如 "3:4" "6:19"）
  final CanvasRatioType type; // 预设/自定义比例标识

  const CanvasConfig({
    required this.width,
    required this.height,
    required this.ratio,
    required this.type,
  });

  /// 从比例字符串创建画布配置（基准宽度750px）
  factory CanvasConfig.fromRatio(String ratio, {double baseWidth = 750.0}) {
    final parts = ratio.split(':');
    if (parts.length != 2) {
      throw ArgumentError('Invalid ratio format: $ratio');
    }
    
    final w = double.tryParse(parts[0]) ?? 1.0;
    final h = double.tryParse(parts[1]) ?? 1.0;
    final height = baseWidth * h / w;
    
    final type = _getRatioType(ratio);
    
    return CanvasConfig(
      width: baseWidth,
      height: height,
      ratio: ratio,
      type: type,
    );
  }

  /// 获取数值比例（宽/高）
  double get numericRatio {
    final parts = ratio.split(':');
    if (parts.length != 2) return 1.0;
    final w = double.tryParse(parts[0]) ?? 1.0;
    final h = double.tryParse(parts[1]) ?? 1.0;
    return w / h;
  }

  /// 判断是否为竖版
  bool get isVertical => numericRatio < 1.0;

  /// 判断是否为横版
  bool get isHorizontal => numericRatio > 1.0;

  static CanvasRatioType _getRatioType(String ratio) {
    switch (ratio) {
      case '3:4':
        return CanvasRatioType.ratio3_4;
      case '1:1':
        return CanvasRatioType.ratio1_1;
      case '16:9':
        return CanvasRatioType.ratioFull16_9;
      case '9:16':
        return CanvasRatioType.ratio9_16;
      case '6:19':
        return CanvasRatioType.ratio6_19;
      default:
        return CanvasRatioType.custom;
    }
  }

  CanvasConfig copyWith({
    double? width,
    double? height,
    String? ratio,
    CanvasRatioType? type,
  }) {
    return CanvasConfig(
      width: width ?? this.width,
      height: height ?? this.height,
      ratio: ratio ?? this.ratio,
      type: type ?? this.type,
    );
  }
}

/// 画布比例类型
enum CanvasRatioType {
  ratio3_4,       // 3:4 竖版
  ratio1_1,       // 1:1 正方形
  ratioFull16_9,  // 16:9 横版（Full）
  ratio9_16,      // 9:16 竖屏
  ratio6_19,      // 6:19 超长竖版
  custom,         // 自定义比例（More）
}
