import 'dart:async';
import 'package:flutter/services.dart';

class LivePhotoBridge {
  static const MethodChannel _channel = MethodChannel('live_photo_bridge');

  /// 获取所有实况照片的 ID 列表
  static Future<List<String>> getLivePhotoIds() async {
    final List<dynamic>? ids = await _channel.invokeMethod('getLivePhotoIds');
    return ids?.cast<String>() ?? [];
  }

  /// 获取指定实况照片的关联视频路径
  static Future<String?> getVideoPath(String assetId) async {
    return await _channel.invokeMethod('getVideoPath', {'assetId': assetId});
  }

  /// 提取视频帧
  static Future<String?> extractFrame(String videoPath, int timeMs) async {
    return await _channel.invokeMethod('extractFrame', {
      'videoPath': videoPath,
      'timeMs': timeMs,
    });
  }

  /// 获取 Live Photo 视频时长（毫秒）
  static Future<int> getVideoDuration(String assetId) async {
    try {
      final result = await _channel.invokeMethod('getVideoDuration', {
        'assetId': assetId,
      });
      return result as int? ?? 0;
    } catch (e) {
      print('❌ 获取视频时长失败: $e');
      return 0;
    }
  }

  /// 🚀 硬件加速：直接从 Live Photo 视频合成（无需提取所有帧，速度快8-10倍）
  static Future<bool> createLivePhotoHardware({
    required List<String> assetIds,
    required Map<String, dynamic> layoutConfig,
    required List<int> coverTimes,
  }) async {
    try {
      print('🚀 调用硬件加速合成: ${assetIds.length}路视频');
      final result = await _channel.invokeMethod('createLivePhotoHardware', {
        'assetIds': assetIds,
        'layoutConfig': layoutConfig,
        'coverTimes': coverTimes,
      });
      return result == true;
    } catch (e) {
      print('❌ 硬件加速合成失败: $e');
      return false;
    }
  }
}
