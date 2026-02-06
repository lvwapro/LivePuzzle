import 'dart:typed_data';
import 'package:live_puzzle/models/frame_data.dart';
import 'package:live_puzzle/models/live_photo.dart';
import 'package:flutter/services.dart';

/// 帧提取器
/// 负责从Live Photo中提取视频帧
class FrameExtractor {
  static const MethodChannel _channel = MethodChannel('live_puzzle/frame_extractor');

  /// 提取指定时间点的帧
  static Future<FrameData?> extractFrameAtTime(
    LivePhoto livePhoto,
    Duration timestamp,
  ) async {
    try {
      final result = await _channel.invokeMethod('extractFrameAtTime', {
        'videoPath': livePhoto.videoPath,
        'timestamp': timestamp.inMilliseconds,
      });

      if (result == null) return null;

      final Map<String, dynamic> frameMap = Map<String, dynamic>.from(result);
      
      return FrameData(
        index: frameMap['index'] as int,
        timestamp: Duration(milliseconds: frameMap['timestamp'] as int),
        imageData: frameMap['imageData'] as Uint8List,
        width: frameMap['width'] as int,
        height: frameMap['height'] as int,
      );
    } catch (e) {
      return null;
    }
  }

  /// 提取指定索引的帧
  static Future<FrameData?> extractFrameAtIndex(
    LivePhoto livePhoto,
    int index,
  ) async {
    try {
      final result = await _channel.invokeMethod('extractFrameAtIndex', {
        'videoPath': livePhoto.videoPath,
        'index': index,
      });

      if (result == null) return null;

      final Map<String, dynamic> frameMap = Map<String, dynamic>.from(result);
      
      return FrameData(
        index: frameMap['index'] as int,
        timestamp: Duration(milliseconds: frameMap['timestamp'] as int),
        imageData: frameMap['imageData'] as Uint8List,
        width: frameMap['width'] as int,
        height: frameMap['height'] as int,
      );
    } catch (e) {
      return null;
    }
  }

  /// 批量提取多个帧（用于预览）
  static Future<List<FrameData>> extractFrames(
    LivePhoto livePhoto, {
    int count = 10,
  }) async {
    try {
      final result = await _channel.invokeMethod('extractFrames', {
        'videoPath': livePhoto.videoPath,
        'count': count,
      });

      if (result == null) return [];

      final List<dynamic> framesList = result as List<dynamic>;
      
      return framesList.map((frameMap) {
        final Map<String, dynamic> frame = Map<String, dynamic>.from(frameMap);
        return FrameData(
          index: frame['index'] as int,
          timestamp: Duration(milliseconds: frame['timestamp'] as int),
          imageData: frame['imageData'] as Uint8List,
          width: frame['width'] as int,
          height: frame['height'] as int,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 获取关键帧
  static Future<List<FrameData>> extractKeyFrames(LivePhoto livePhoto) async {
    try {
      final result = await _channel.invokeMethod('extractKeyFrames', {
        'videoPath': livePhoto.videoPath,
      });

      if (result == null) return [];

      final List<dynamic> framesList = result as List<dynamic>;
      
      return framesList.map((frameMap) {
        final Map<String, dynamic> frame = Map<String, dynamic>.from(frameMap);
        return FrameData(
          index: frame['index'] as int,
          timestamp: Duration(milliseconds: frame['timestamp'] as int),
          imageData: frame['imageData'] as Uint8List,
          width: frame['width'] as int,
          height: frame['height'] as int,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 获取封面帧（第一帧）
  static Future<FrameData?> extractCoverFrame(LivePhoto livePhoto) async {
    return await extractFrameAtIndex(livePhoto, 0);
  }
}
