import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:live_photo_bridge/live_photo_bridge.dart';

/// Live Photo管理器
/// 负责识别、加载和处理Live Photo/Motion Photo
/// 支持iOS Live Photo和Android Motion Photo（包括vivo、小米等设备）
class LivePhotoManager {
  /// 每页加载的数量
  static const int pageSize = 30;

  /// 调试模式：将所有图片视为Live Photo（用于测试）
  static bool debugModeShowAllAsLive = false;

  /// 获取所有实况照片 ID (通过桥接)
  static Future<List<String>> getBridgeLivePhotoIds() async {
    try {
      return await LivePhotoBridge.getLivePhotoIds();
    } catch (e) {
      debugPrint('❌ 桥接获取实况 ID 失败: $e');
      return [];
    }
  }

  /// 获取所有照片（支持按相册筛选和限制数量）
  /// [albumId] 相册ID，null表示获取"最近项目"相册
  /// [limit] 限制加载数量，null表示加载全部
  static Future<List<AssetEntity>> getAllPhotos({
    String? albumId,
    int? limit,
  }) async {
    debugPrint(
        '📸 开始加载照片... ${albumId != null ? "相册ID: $albumId" : "最近项目"} ${limit != null ? "限制: $limit 张" : "全部"}');

    try {
      // 获取所有相册（只获取图片类型）
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image, // 🔥 只获取图片，不包含视频
        hasAll: true,
      );

      debugPrint('📁 找到 ${albums.length} 个相册');

      // 查找目标相册
      AssetPathEntity? targetAlbum;
      if (albumId != null) {
        // 根据ID查找指定相册
        targetAlbum = albums.firstWhere(
          (album) => album.id == albumId,
          orElse: () => albums.firstWhere((album) => album.isAll),
        );
      } else {
        // 默认查找"最近项目"相册
        for (final album in albums) {
          if (album.isAll) {
            targetAlbum = album;
            break;
          }
        }
      }

      if (targetAlbum == null) return [];

      final assetCount = await targetAlbum.assetCountAsync;
      debugPrint('📁 相册: ${targetAlbum.name}, 照片总数: $assetCount');

      // 🔥 根据 limit 参数决定加载数量
      final loadCount = limit != null && limit < assetCount ? limit : assetCount;

      final assets = await targetAlbum.getAssetListRange(
        start: 0,
        end: loadCount,
      );

      debugPrint('📸 成功加载 ${assets.length} 张照片（总共 $assetCount 张）');
      return assets;
    } catch (e, stack) {
      debugPrint('❌ 加载照片失败: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  /// 获取缩略图数据
  static Future<Uint8List?> getThumbnailData(
    AssetEntity asset, {
    int size = 400,
  }) async {
    try {
      return await asset.thumbnailDataWithSize(
        ThumbnailSize(size, size),
        quality: 90,
      );
    } catch (e) {
      debugPrint('❌ 获取缩略图失败: $e');
      return null;
    }
  }

  /// 检查是否为 Live Photo / Motion Photo
  /// 综合 iOS 和 Android 的多种识别策略
  static Future<bool> isLivePhoto(AssetEntity asset) async {
    // 调试模式：所有图片都算Live Photo
    if (debugModeShowAllAsLive && asset.type == AssetType.image) {
      return true;
    }

    try {
      // 策略1: 使用 photo_manager 提供的标准属性 (iOS 和 部分 Android)
      if (asset.isLivePhoto) {
        debugPrint('✅ 检测到 Live Photo (标准属性): ${asset.id}');
        return true;
      }

      // 策略2: 针对 iOS 的补充检测
      if (Platform.isIOS) {
        // 检查视频时长
        if (asset.type == AssetType.image &&
            asset.videoDuration.inMilliseconds > 0) {
          debugPrint('✅ iOS Live Photo (视频时长): ${asset.id}');
          return true;
        }
        // 检查文件路径特征
        final originFile = await asset.originFile;
        if (originFile != null) {
          final path = originFile.path.toLowerCase();
          if (path.contains('pvt') || path.contains('live')) {
            debugPrint('✅ iOS Live Photo (路径特征): ${asset.id}');
            return true;
          }
        }
      }

      // 策略3: 针对 Android 的深度检测 (处理不同品牌)
      if (Platform.isAndroid && asset.type == AssetType.image) {
        // 1. 检查是否有关联的视频时长 (部分 Android 动态照片会暴露时长)
        if (asset.videoDuration.inMilliseconds > 0) {
          debugPrint('✅ Android Motion Photo (关联时长): ${asset.id}');
          return true;
        }

        // 2. 检查文件名和文件头 (启发式检测)
        final file = await asset.originFile;
        if (file != null) {
          final fileName = file.path.toLowerCase();
          final size = await file.length();

          // 许多 Android 设备的动态照片文件名包含 MV, MP, 或 Motion
          if (fileName.contains('mvimg') ||
              fileName.contains('motion') ||
              fileName.contains('mpimg')) {
            debugPrint('✅ Android Motion Photo (文件名特征): ${asset.id}');
            return true;
          }

          // 3. 检查文件大小 (Motion Photo 通常比普通照片大很多，因为它内嵌了 MP4)
          if (size > 4 * 1024 * 1024) {
            debugPrint(
                '🔍 可能是 Android Motion Photo (大文件): ${asset.id}, 大小: ${(size / 1024 / 1024).toStringAsFixed(2)}MB');
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('❌ 检测 Live Photo 失败: $e');
      return false;
    }
  }

  /// 获取所有 Live Photos（支持分批加载和相册筛选）
  /// [limit] 限制加载数量，null表示加载全部
  /// [albumId] 相册ID，null表示从所有相册获取
  static Future<List<AssetEntity>> getLivePhotosOnly({
    int? limit,
    String? albumId,
  }) async {
    debugPrint(
        '📸 开始加载实况照片... ${limit != null ? "限制: $limit 张" : "全部"} ${albumId != null ? "相册ID: $albumId" : "所有相册"}');
    debugPrint('🔧 调试模式: ${debugModeShowAllAsLive ? "开启(所有图片算Live)" : "关闭"}');

    try {
      // 如果指定了相册，需要先过滤相册中的实况照片
      if (albumId != null) {
        return await _getLivePhotosFromAlbum(albumId, limit);
      }

      // 优先尝试通过原生桥接获取 ID（全局实况照片）
      final bridgeIds = await getBridgeLivePhotoIds();
      if (bridgeIds.isNotEmpty) {
        debugPrint('✅ 原生桥接找到 ${bridgeIds.length} 张实况照片');
        final List<AssetEntity> assets = [];

        // 🔥 确定要加载的数量
        final loadCount = limit ?? bridgeIds.length;
        final actualLoadCount = loadCount < bridgeIds.length ? loadCount : bridgeIds.length;

        // 🔥 批量加载，提高性能
        for (int i = 0; i < actualLoadCount; i++) {
          try {
            final asset = await AssetEntity.fromId(bridgeIds[i]);
            if (asset != null) {
              assets.add(asset);
            } else {
              debugPrint('⚠️ 无法加载资源: ${bridgeIds[i]}');
            }
          } catch (e) {
            debugPrint('⚠️ 加载资源失败: ${bridgeIds[i]}, 错误: $e');
          }
        }
        
        debugPrint(
            '📸 成功加载 ${assets.length} 张实况照片${limit != null && actualLoadCount < bridgeIds.length ? " (还有 ${bridgeIds.length - actualLoadCount} 张待加载)" : ""}');
        return assets;
      }

      // 如果桥接没拿到，回退到深度扫描模式
      debugPrint('🔍 桥接未获取到数据，回退到深度扫描模式');

      // 获取所有相册
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
      );

      if (albums.isEmpty) return [];

      // 找到包含所有照片的相册
      AssetPathEntity? album;
      for (final a in albums) {
        if (a.isAll) {
          album = a;
          break;
        }
      }
      if (album == null) return [];

      final assetCount = await album.assetCountAsync;

      // 如果是调试模式，直接返回指定数量的照片
      if (debugModeShowAllAsLive) {
        final loadCount =
            limit != null && limit < assetCount ? limit : assetCount;
        return await album.getAssetListRange(start: 0, end: loadCount);
      }

      final livePhotos = <AssetEntity>[];
      const int batchSize = 100;
      int currentOffset = 0;

      debugPrint('🔍 开始深度扫描实况照片... (总数: $assetCount)');

      while (currentOffset < assetCount) {
        // 如果设置了限制且已达到，停止加载
        if (limit != null && livePhotos.length >= limit) {
          break;
        }

        final end = (currentOffset + batchSize > assetCount)
            ? assetCount
            : currentOffset + batchSize;
        final assets = await album.getAssetListRange(
          start: currentOffset,
          end: end,
        );

        for (final asset in assets) {
          if (await isLivePhoto(asset)) {
            livePhotos.add(asset);
            // 如果达到限制，停止
            if (limit != null && livePhotos.length >= limit) {
              break;
            }
          }
        }

        currentOffset += batchSize;
        debugPrint(
            '⏳ 已扫描 $currentOffset/$assetCount 张，找到 ${livePhotos.length} 张实况');
      }

      debugPrint('📸 成功加载 ${livePhotos.length} 张实况照片');
      return livePhotos;
    } catch (e, stack) {
      debugPrint('❌ 加载实况照片失败: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  /// 从指定相册获取实况照片
  static Future<List<AssetEntity>> _getLivePhotosFromAlbum(
    String albumId,
    int? limit,
  ) async {
    debugPrint('📁 从指定相册加载实况照片... 相册ID: $albumId');

    try {
      // 获取所有相册
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
      );

      // 查找目标相册
      AssetPathEntity? targetAlbum;
      for (final album in albums) {
        if (album.id == albumId || (albumId == 'all' && album.isAll)) {
          targetAlbum = album;
          break;
        }
      }

      if (targetAlbum == null) {
        debugPrint('❌ 未找到相册: $albumId');
        return [];
      }

      final assetCount = await targetAlbum.assetCountAsync;
      debugPrint('📁 相册: ${targetAlbum.name}, 照片总数: $assetCount');

      // 获取相册中的所有照片
      final allAssets = await targetAlbum.getAssetListRange(
        start: 0,
        end: assetCount,
      );

      // 获取所有实况照片的ID
      final livePhotoIds = await getBridgeLivePhotoIds();
      final livePhotoIdSet = livePhotoIds.toSet();

      // 筛选出该相册中的实况照片
      final livePhotos = <AssetEntity>[];
      for (final asset in allAssets) {
        if (livePhotoIdSet.contains(asset.id)) {
          livePhotos.add(asset);
          // 如果达到限制，停止
          if (limit != null && livePhotos.length >= limit) {
            break;
          }
        }
      }

      debugPrint('📸 在相册 ${targetAlbum.name} 中找到 ${livePhotos.length} 张实况照片');
      return livePhotos;
    } catch (e, stack) {
      debugPrint('❌ 从相册加载实况照片失败: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  /// 获取视频文件（用于播放动态部分）
  /// 只通过原生桥接获取，确保可靠性
  static Future<File?> getVideoFile(AssetEntity asset) async {
    try {
      debugPrint('🎬 开始获取视频文件: ${asset.id}');

      // 只使用原生桥接获取视频路径（iOS和Android统一）
      final bridgePath = await LivePhotoBridge.getVideoPath(asset.id);

      if (bridgePath != null) {
        final videoFile = File(bridgePath);
        if (await videoFile.exists()) {
          debugPrint('✅ 通过原生桥接获取到视频: $bridgePath');
          return videoFile;
        } else {
          debugPrint('⚠️ 视频文件不存在: $bridgePath');
        }
      } else {
        debugPrint('⚠️ 原生桥接返回空路径');
      }

      return null;
    } catch (e, stack) {
      debugPrint('❌ 获取视频文件失败: $e');
      debugPrint('Stack trace: $stack');
      return null;
    }
  }

}
