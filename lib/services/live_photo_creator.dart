import 'dart:io';
import 'package:flutter/services.dart';
import 'package:live_puzzle/models/puzzle_project.dart';
import 'package:live_puzzle/models/frame_data.dart';
import 'package:live_puzzle/models/live_photo.dart';
import 'package:live_puzzle/services/puzzle_generator.dart';
import 'package:live_puzzle/services/frame_extractor.dart';
import 'package:live_puzzle/services/live_photo_manager.dart';
import 'package:live_puzzle/utils/file_helpers.dart';

/// Live Photo创建器
/// 核心功能：将拼图重新生成为Live Photo格式，保留动态效果
class LivePhotoCreator {
  static const MethodChannel _channel = MethodChannel('live_puzzle/creator');

  /// 创建Live Photo
  /// 
  /// 核心逻辑：
  /// 1. 为每个原始Live Photo提取所有帧
  /// 2. 对每一帧生成对应的拼图图片
  /// 3. 将拼图图片序列合成为视频
  /// 4. 生成静态拼图作为封面（使用用户选择的定格帧）
  /// 5. 组合封面和视频为Live Photo格式
  static Future<File?> createLivePhoto(
    PuzzleProject project, {
    int outputWidth = 1080,
    int outputHeight = 1080,
    Duration? targetDuration,
  }) async {
    try {
      // 1. 获取所有原始Live Photo对象
      final livePhotos = await _getLivePhotosFromProject(project);
      if (livePhotos.isEmpty) {
        print('❌ 没有找到Live Photo');
        return null;
      }

      // 2. 确定视频时长（使用最短的Live Photo时长）
      final duration = targetDuration ??
          livePhotos
              .map((lp) => lp.duration)
              .reduce((a, b) => a < b ? a : b);

      print('📹 视频时长: ${duration.inMilliseconds}ms');

      // 3. 提取所有Live Photo的所有帧
      print('🎬 开始提取帧...');
      final allFramesList = await _extractAllFramesFromLivePhotos(
        livePhotos,
        duration,
      );

      if (allFramesList.isEmpty || allFramesList.any((list) => list.isEmpty)) {
        print('❌ 提取帧失败');
        return null;
      }

      // 4. 生成拼图帧序列
      print('🖼️ 开始生成拼图帧序列...');
      final frameFiles = await _generatePuzzleFrameSequence(
        project,
        allFramesList,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
      );

      if (frameFiles.isEmpty) {
        print('❌ 生成拼图帧序列失败');
        return null;
      }

      print('✅ 生成了 ${frameFiles.length} 个拼图帧');

      // 5. 生成静态拼图封面（使用用户选择的定格帧）
      print('🎨 生成拼图封面...');
      final coverImage = await PuzzleGenerator.generatePuzzleImage(
        project,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
      );

      if (coverImage == null) {
        await _cleanupFiles(frameFiles);
        print('❌ 生成封面失败');
        return null;
      }

      // 6. 使用帧序列创建视频
      print('🎥 合成视频...');
      final videoFile = await _createVideoFromFrames(
        frameFiles,
        duration: duration,
      );

      if (videoFile == null) {
        await _cleanupFiles(frameFiles);
        await coverImage.delete();
        print('❌ 视频合成失败');
        return null;
      }

      print('✅ 视频合成完成: ${videoFile.path}');

      // 7. 组合成Live Photo格式
      print('📦 组合Live Photo...');
      final livePhotoFile = await _combineCoverAndVideo(
        coverImage,
        videoFile,
      );

      // 8. 清理临时文件
      print('🧹 清理临时文件...');
      await _cleanupFiles(frameFiles);
      await coverImage.delete();
      await videoFile.delete();

      if (livePhotoFile != null) {
        print('✅ Live Photo创建成功: ${livePhotoFile.path}');
      } else {
        print('❌ Live Photo创建失败');
      }

      return livePhotoFile;
    } catch (e, stack) {
      print('❌ 创建Live Photo时出错: $e');
      print(stack);
      return null;
    }
  }

  /// 从项目中获取所有Live Photo对象
  static Future<List<LivePhoto>> _getLivePhotosFromProject(
      PuzzleProject project) async {
    final livePhotos = <LivePhoto>[];
    final uniqueIds = <String>{};

    for (final frame in project.frames) {
      if (!uniqueIds.contains(frame.livePhotoId)) {
        uniqueIds.add(frame.livePhotoId);
        final livePhoto =
            await LivePhotoManager.getLivePhotoById(frame.livePhotoId);
        if (livePhoto != null) {
          livePhotos.add(livePhoto);
        }
      }
    }

    return livePhotos;
  }

  /// 从所有Live Photo中提取帧序列
  static Future<List<List<FrameData>>> _extractAllFramesFromLivePhotos(
    List<LivePhoto> livePhotos,
    Duration targetDuration,
  ) async {
    final allFramesList = <List<FrameData>>[];

    // 每秒10帧
    const fps = 10;
    final totalFrames = (targetDuration.inMilliseconds / 1000 * fps).round();

    for (final livePhoto in livePhotos) {
      final frames = <FrameData>[];

      for (int i = 0; i < totalFrames; i++) {
        final timestamp = Duration(
          milliseconds: (i * 1000 / fps).round(),
        );

        final frame = await FrameExtractor.extractFrameAtTime(
          livePhoto,
          timestamp,
        );

        if (frame != null) {
          frames.add(frame);
        } else {
          // 如果提取失败，使用上一帧或者第一帧
          if (frames.isNotEmpty) {
            frames.add(frames.last);
          }
        }
      }

      allFramesList.add(frames);
    }

    return allFramesList;
  }

  /// 生成拼图帧序列
  static Future<List<File>> _generatePuzzleFrameSequence(
    PuzzleProject project,
    List<List<FrameData>> allFramesList, {
    required int outputWidth,
    required int outputHeight,
  }) async {
    final frameFiles = <File>[];

    try {
      // 确定帧数（使用最短的序列长度）
      final frameCount = allFramesList
          .map((list) => list.length)
          .reduce((a, b) => a < b ? a : b);

      for (int frameIndex = 0; frameIndex < frameCount; frameIndex++) {
        // 为当前帧索引创建拼图
        final currentFrames = <SelectedFrame>[];

        for (int photoIndex = 0;
            photoIndex < project.frames.length;
            photoIndex++) {
          final originalFrame = project.frames[photoIndex];

          // 获取该Live Photo在当前时间的帧
          if (photoIndex < allFramesList.length) {
            final framesForThisPhoto = allFramesList[photoIndex];
            final actualFrameIndex = frameIndex < framesForThisPhoto.length
                ? frameIndex
                : framesForThisPhoto.length - 1;

            currentFrames.add(
              originalFrame.copyWith(
                frameData: framesForThisPhoto[actualFrameIndex],
              ),
            );
          }
        }

        // 生成当前帧的拼图
        final currentProject = project.copyWith(frames: currentFrames);
        final frameFile = await PuzzleGenerator.generatePuzzleImage(
          currentProject,
          outputWidth: outputWidth,
          outputHeight: outputHeight,
        );

        if (frameFile != null) {
          frameFiles.add(frameFile);
        } else {
          // 生成失败，清理并返回
          await _cleanupFiles(frameFiles);
          return [];
        }

        // 打印进度
        if ((frameIndex + 1) % 5 == 0 || frameIndex == frameCount - 1) {
          print('  进度: ${frameIndex + 1}/$frameCount');
        }
      }

      return frameFiles;
    } catch (e) {
      await _cleanupFiles(frameFiles);
      print('生成拼图帧序列时出错: $e');
      return [];
    }
  }

  /// 使用FFmpeg从帧序列创建视频
  static Future<File?> _createVideoFromFrames(
    List<File> frameFiles, {
    required Duration duration,
  }) async {
    try {
      final outputPath = await FileHelper.createTempFilePath('mp4');

      final framePaths = frameFiles.map((f) => f.path).toList();
      final fps = (frameFiles.length / (duration.inMilliseconds / 1000))
          .round()
          .clamp(10, 30);

      print('  帧数: ${frameFiles.length}, FPS: $fps');

      final result = await _channel.invokeMethod('createVideoFromFrames', {
        'framePaths': framePaths,
        'outputPath': outputPath,
        'duration': duration.inMilliseconds,
        'fps': fps,
      });

      if (result == true && await File(outputPath).exists()) {
        return File(outputPath);
      }

      return null;
    } catch (e) {
      print('创建视频时出错: $e');
      return null;
    }
  }

  /// 组合封面图片和视频为Live Photo
  static Future<File?> _combineCoverAndVideo(
    File coverImage,
    File videoFile,
  ) async {
    try {
      final outputPath = await FileHelper.createTempFilePath(
        Platform.isIOS ? 'mov' : 'jpg',
      );

      if (Platform.isIOS) {
        return await _createIOSLivePhoto(coverImage, videoFile, outputPath);
      } else if (Platform.isAndroid) {
        return await _createAndroidMotionPhoto(
            coverImage, videoFile, outputPath);
      }

      return null;
    } catch (e) {
      print('组合Live Photo时出错: $e');
      return null;
    }
  }

  /// 创建iOS Live Photo
  static Future<File?> _createIOSLivePhoto(
    File coverImage,
    File videoFile,
    String outputPath,
  ) async {
    try {
      final result = await _channel.invokeMethod('createLivePhoto', {
        'imagePath': coverImage.path,
        'videoPath': videoFile.path,
        'outputPath': outputPath,
      });

      if (result == true && await File(outputPath).exists()) {
        return File(outputPath);
      }

      return null;
    } catch (e) {
      print('创建iOS Live Photo时出错: $e');
      return null;
    }
  }

  /// 创建Android Motion Photo
  static Future<File?> _createAndroidMotionPhoto(
    File coverImage,
    File videoFile,
    String outputPath,
  ) async {
    try {
      final result = await _channel.invokeMethod('createMotionPhoto', {
        'imagePath': coverImage.path,
        'videoPath': videoFile.path,
        'outputPath': outputPath,
      });

      if (result == true && await File(outputPath).exists()) {
        return File(outputPath);
      }

      return null;
    } catch (e) {
      print('创建Android Motion Photo时出错: $e');
      return null;
    }
  }

  /// 保存Live Photo到相册
  static Future<bool> saveLivePhotoToGallery(File livePhotoFile) async {
    try {
      final result = await _channel.invokeMethod('saveToGallery', {
        'filePath': livePhotoFile.path,
      });

      return result as bool? ?? false;
    } catch (e) {
      print('保存到相册时出错: $e');
      return false;
    }
  }

  /// 清理临时文件
  static Future<void> _cleanupFiles(List<File> files) async {
    for (final file in files) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // 忽略删除错误
      }
    }
  }
}
