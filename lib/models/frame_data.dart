import 'dart:typed_data';

/// 帧数据模型
class FrameData {
  final int index;
  final Duration timestamp;
  final Uint8List imageData;
  final int width;
  final int height;

  const FrameData({
    required this.index,
    required this.timestamp,
    required this.imageData,
    required this.width,
    required this.height,
  });

  FrameData copyWith({
    int? index,
    Duration? timestamp,
    Uint8List? imageData,
    int? width,
    int? height,
  }) {
    return FrameData(
      index: index ?? this.index,
      timestamp: timestamp ?? this.timestamp,
      imageData: imageData ?? this.imageData,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  double get timestampInSeconds => timestamp.inMilliseconds / 1000.0;
}

/// 选中的帧信息
class SelectedFrame {
  final String livePhotoId;
  final FrameData frameData;
  final int positionInPuzzle;

  const SelectedFrame({
    required this.livePhotoId,
    required this.frameData,
    required this.positionInPuzzle,
  });

  SelectedFrame copyWith({
    String? livePhotoId,
    FrameData? frameData,
    int? positionInPuzzle,
  }) {
    return SelectedFrame(
      livePhotoId: livePhotoId ?? this.livePhotoId,
      frameData: frameData ?? this.frameData,
      positionInPuzzle: positionInPuzzle ?? this.positionInPuzzle,
    );
  }
}
