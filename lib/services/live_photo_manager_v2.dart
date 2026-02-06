import 'dart:io';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:live_puzzle/models/live_photo.dart';

/// Live Photo管理器
/// 负责识别、加载和处理Live Photo/Motion Photo
class LivePhotoManager {
  static const MethodChannel _channel = MethodChannel('live_puzzle/live_photo');

  /// 获取所有Live Photo（最简化版本：直接使用AssetEntity）
  static Future<List<LivePhoto>> getAllLivePhotos() async {
    print('📸 开始加载照片...');
    
    try {
      // 获取所有相册
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );
      
      print('📁 找到 ${albums.length} 个相册');

      final List<LivePhoto> livePhotos = [];

      // 只处理"最近项目"相册
      for (final album in albums) {
        if (album.isAll) {
          final assetCount = await album.assetCountAsync;
          print('📁 相册: ${album.name}, 照片数: $assetCount');
          
          // 只加载最近的50张照片
          final maxCount = assetCount > 50 ? 50 : assetCount;
          final assets = await album.getAssetListRange(
            start: 0,
            end: maxCount,
          );

          print('📸 正在处理最近的 ${assets.length} 张照片...');

          // 直接使用AssetEntity，不生成缩略图文件
          for (final asset in assets) {
            try {
              livePhotos.add(LivePhoto(
                id: asset.id,
                imagePath: asset.id, // 使用ID作为路径
                videoPath: '',
                duration: const Duration(seconds: 3),
                createdAt: asset.createDateTime,
                frameCount: 30,
                imageFile: null, // 不使用文件
                videoFile: null,
              ));
            } catch (e) {
              print('⚠️ 处理照片失败: ${asset.id}, 错误: $e');
            }
          }
          
          print('✅ 总共加载了 ${livePhotos.length} 张照片');
          break;
        }
      }

      return livePhotos;
    } catch (e, stack) {
      print('❌ 加载照片失败: $e');
      print('Stack trace: $stack');
      rethrow;
    }
  }

  /// 获取指定Live Photo的详细信息
  static Future<LivePhoto?> getLivePhotoById(String id) async {
    try {
      final asset = await AssetEntity.fromId(id);
      if (asset == null) return null;
      
      return LivePhoto(
        id: asset.id,
        imagePath: asset.id,
        videoPath: '',
        duration: const Duration(seconds: 3),
        createdAt: asset.createDateTime,
        frameCount: 30,
        imageFile: null,
        videoFile: null,
      );
    } catch (e) {
      print('❌ 获取照片详情失败: $e');
      return null;
    }
  }
}
