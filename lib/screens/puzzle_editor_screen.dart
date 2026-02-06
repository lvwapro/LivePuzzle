import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_puzzle/providers/photo_provider.dart';
import 'package:live_puzzle/services/live_photo_manager.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:live_photo_bridge/live_photo_bridge.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

// 导入拆分的组件
import 'puzzle_editor/editor_header_widget.dart';
import 'puzzle_editor/puzzle_grid_widget.dart';
import 'puzzle_editor/video_frame_selector_widget.dart';
import 'puzzle_editor/feature_buttons_widget.dart';

/// 拼图编辑器页面 - Seamless Puzzle风格
class PuzzleEditorScreen extends ConsumerStatefulWidget {
  const PuzzleEditorScreen({super.key});

  @override
  ConsumerState<PuzzleEditorScreen> createState() =>
      _PuzzleEditorScreenState();
}

class _PuzzleEditorScreenState extends ConsumerState<PuzzleEditorScreen> 
    with TickerProviderStateMixin {
  
  int _selectedCellIndex = 0;
  List<AssetEntity> _selectedPhotos = [];
  final Map<int, Uint8List?> _photoThumbnails = {};
  
  // 🔥 视频播放器相关
  final Map<int, VideoPlayerController?> _videoControllers = {};
  final Map<int, String?> _videoPaths = {}; // 存储视频文件路径
  final Map<int, int> _videoDurations = {}; // 存储视频时长（毫秒）
  int _maxDurationMs = 2000;
  
  // 🔥 封面帧：存储截取的封面图片
  final Map<int, Uint8List?> _coverFrames = {}; // null 表示使用原始封面
  final Map<int, int?> _coverFrameTime = {}; // 存储封面帧的时间点（毫秒）
  
  // 🔥 Live 拼图播放
  AnimationController? _animationController;
  Animation<double>? _animation;
  bool _isPlayingLivePuzzle = false;
  
  // 🔥 当前显示的图片（用于网格显示）
  final Map<int, Uint8List?> _currentDisplayImages = {};
  AnimationController? _animationController;
  Animation<double>? _animation;
  bool _isPlayingLivePuzzle = false;

  @override
  void initState() {
    super.initState();
    
    // 🔥 初始化动画控制器 - 2秒完成一个循环
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    // 🔥 创建线性动画，从0到1 - 使用 AnimatedBuilder，不需要手动 setState
    _animation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.linear,
    );
    
    // 🔥 监听动画完成
    _animationController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          debugPrint('🎬 动画完成，恢复封面帧: $_coverFrames');
          setState(() {
            _isPlayingLivePuzzle = false;
            // 🔥 恢复到各自的封面帧（null=原始封面，非null=指定帧）
            for (int i = 0; i < _selectedPhotos.length; i++) {
              final coverFrame = _coverFrames[i];
              if (coverFrame == null) {
                // 使用原始封面，这里暂时设为 -1 表示显示缩略图
                _selectedFrames[i] = -1;
              } else {
                // 使用指定的视频帧
                _selectedFrames[i] = coverFrame;
              }
              debugPrint('  格子 $i: 恢复到${coverFrame == null ? "原始封面" : "帧 $coverFrame"}');
            }
          });
          _animationController?.reset();
        }
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSelectedPhotos();
    });
  }

  @override
  void dispose() {
    _animationController?.dispose();
    // 🔥 释放所有视频播放器
    for (final controller in _videoControllers.values) {
      controller?.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSelectedPhotos() async {
    final selectedAllIds = ref.read(selectedAllPhotoIdsProvider);
    final selectedLiveIds = ref.read(selectedLivePhotoIdsProvider);
    
    final selectedIds = selectedLiveIds.isNotEmpty ? selectedLiveIds : selectedAllIds;
    
    final livePhotosAsync = ref.read(livePhotoListProvider);
    
    livePhotosAsync.whenData((photos) async {
      final selectedAssets = <AssetEntity>[];
      
      for (final id in selectedIds) {
        try {
          final asset = await AssetEntity.fromId(id);
          if (asset != null) {
            selectedAssets.add(asset);
          }
        } catch (e) {
          debugPrint('Error loading asset $id: $e');
        }
      }
      
      if (mounted) {
        setState(() {
          _selectedPhotos = selectedAssets;
          // 🔥 初始化封面帧和选中帧
          for (int i = 0; i < selectedAssets.length; i++) {
            if (!_coverFrames.containsKey(i)) {
              _coverFrames[i] = null; // 🔥 null 表示使用原始封面（Live Photo 的静态图）
            }
            if (!_selectedFrames.containsKey(i)) {
              _selectedFrames[i] = 0; // 🔥 初始显示第一帧
            }
          }
        });

        // 🔥 获取所有 Live Photo 的视频时长，找到最长的
        int maxDurationMs = 2000; // 默认2秒
        for (int i = 0; i < selectedAssets.length; i++) {
          final asset = selectedAssets[i];
          try {
            final durationMs = await LivePhotoBridge.getVideoDuration(asset.id);
            _videoDurations[i] = durationMs; // 存储每个 Live Photo 的时长
            if (durationMs > maxDurationMs) {
              maxDurationMs = durationMs;
            }
            debugPrint('📹 Live Photo $i (${asset.id}) 时长: ${durationMs}ms');
          } catch (e) {
            _videoDurations[i] = 2000; // 出错时默认2秒
            debugPrint('Error getting duration: $e');
          }
        }
        
        _maxDurationMs = maxDurationMs;
        debugPrint('🎬 最长 Live Photo 时长: ${maxDurationMs}ms');
        
        // 🔥 更新动画时长
        if (mounted) {
          _animationController?.dispose();
          _animationController = AnimationController(
            duration: Duration(milliseconds: maxDurationMs),
            vsync: this,
          );
          
          _animation = CurvedAnimation(
            parent: _animationController!,
            curve: Curves.linear,
          );
          
          // 重新添加监听器
          _animationController!.addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              if (mounted) {
                setState(() {
                  _isPlayingLivePuzzle = false;
                  // 🔥 恢复到各自的封面帧
                  for (int i = 0; i < _selectedPhotos.length; i++) {
                    final coverFrame = _coverFrames[i];
                    if (coverFrame == null) {
                      _selectedFrames[i] = -1; // 使用原始封面
                    } else {
                      _selectedFrames[i] = coverFrame;
                    }
                  }
                });
                _animationController?.reset();
              }
            }
          });
        }

        for (int i = 0; i < _selectedPhotos.length; i++) {
          try {
            // 🔥 提高缩略图质量，用于显示和保存
            final thumbnail = await _selectedPhotos[i].thumbnailDataWithSize(
              const ThumbnailSize(1200, 1200), // 提高到 1200x1200
              quality: 95, // 提高质量
            );
            if (mounted && thumbnail != null) {
              setState(() {
                _photoThumbnails[i] = thumbnail;
              });
            }
          } catch (e) {
            debugPrint('Error loading thumbnail $i: $e');
          }
        }
      }
    });
  }

  // 🔥 初始化视频播放器用于帧选择
  Future<void> _initVideoPlayer(int cellIndex) async {
    if (cellIndex >= _selectedPhotos.length) return;
    if (_videoControllers[cellIndex] != null) return; // 已初始化
    
    final asset = _selectedPhotos[cellIndex];
    
    try {
      final isLive = await LivePhotoManager.isLivePhoto(asset);
      if (!isLive) return;
      
      final videoPath = await LivePhotoBridge.getVideoPath(asset.id);
      if (videoPath == null || videoPath.isEmpty) return;
      
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) return;
      
      // 存储视频路径
      setState(() {
        _videoPaths[cellIndex] = videoPath;
      });
      
      // 初始化视频播放器
      final controller = VideoPlayerController.file(videoFile);
      await controller.initialize();
      await controller.setLooping(false);
      await controller.pause();
      await controller.seekTo(Duration.zero);
      
      if (mounted) {
        setState(() {
          _videoControllers[cellIndex] = controller;
        });
      }
    } catch (e) {
      debugPrint('⚠️ 初始化视频播放器失败: $e');
    }
  }
  
  // 🔥 截取当前视频帧作为封面
  Future<Uint8List?> _captureVideoFrame(int cellIndex) async {
    final videoPath = _videoPaths[cellIndex];
    if (videoPath == null) return null;
    
    final controller = _videoControllers[cellIndex];
    if (controller == null || !controller.value.isInitialized) return null;
    
    try {
      final timeMs = controller.value.position.inMilliseconds;
      final framePath = await LivePhotoBridge.extractFrame(videoPath, timeMs);
      
      if (framePath != null) {
        final frameFile = File(framePath);
        if (await frameFile.exists()) {
          final frameData = await frameFile.readAsBytes();
          try {
            await frameFile.delete();
          } catch (e) {
            debugPrint('⚠️ 删除临时帧文件失败: $e');
          }
          return frameData;
        }
      }
    } catch (e) {
      debugPrint('⚠️ 截取视频帧失败: $e');
    }
    
    return null;
  }

  Future<void> _extractVideoFrames(int cellIndex) async {
    // 🔥 不再需要提取所有帧，直接初始化视频播放器
    await _initVideoPlayer(cellIndex);
  }

  Future<void> _playLivePuzzle() async {
    if (_animationController == null || _animation == null) return;
    
    if (_isPlayingLivePuzzle) {
      // 🔥 停止播放，恢复到各自的封面帧
      setState(() {
        _isPlayingLivePuzzle = false;
      });
      _animationController?.stop();
      _animationController?.reset();
      // 恢复到各自的封面帧
      for (int i = 0; i < _selectedPhotos.length; i++) {
        final coverFrame = _coverFrames[i];
        _selectedFrames[i] = coverFrame ?? -1; // null 表示原始封面
      }
      return;
    }
    
    // 确保所有照片的帧都已加载
    bool needsLoading = false;
    for (int i = 0; i < _selectedPhotos.length; i++) {
      if (!_videoFrames.containsKey(i)) {
        needsLoading = true;
      }
    }
    
    if (needsLoading) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在准备视频帧，请稍候...'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFFFF4D7D),
          ),
        );
      }
      
      await Future.wait(
        List.generate(_selectedPhotos.length, (i) {
          if (!_videoFrames.containsKey(i)) {
            return _extractVideoFrames(i);
          }
          return Future.value();
        }),
      );
    }
    
    setState(() {
      _isPlayingLivePuzzle = true;
    });
    
    _animationController?.forward(from: 0.0);
  }

  // 🔥 保存拼图到图库（Live Photo 格式）
  Future<void> _savePuzzleToGallery() async {
    if (_selectedPhotos.isEmpty) return;
    
    try {
      // 显示加载提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在生成 Live Photo...'),
            duration: Duration(seconds: 30),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFFFF4D7D),
          ),
        );
      }
      
      // 1. 确保所有帧都已加载
      for (int i = 0; i < _selectedPhotos.length; i++) {
        if (!_videoFrames.containsKey(i)) {
          await _extractVideoFrames(i);
        }
      }
      
      // 2. 为每一帧创建拼接图片（直接拼接原始帧）
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final frameImagePaths = <String>[];
      
      // 🔥 第一帧特殊处理：作为静态封面，所有格子显示封面图
      // 使用缩略图保证清晰度的同时尺寸一致
      final coverCellFrames = <Uint8List>[];
      for (int i = 0; i < _selectedPhotos.length; i++) {
        final coverFrame = _coverFrames[i];
        if (coverFrame == null) {
          // 没设置封面，使用缩略图（已经是1200x1200高质量）
          if (_photoThumbnails[i] != null) {
            coverCellFrames.add(_photoThumbnails[i]!);
          }
        } else {
          // 设置了封面，使用指定帧
          final frames = _videoFrames[i];
          if (frames != null && frames.isNotEmpty) {
            coverCellFrames.add(frames[coverFrame.clamp(0, frames.length - 1)]);
          } else if (_photoThumbnails[i] != null) {
            coverCellFrames.add(_photoThumbnails[i]!);
          }
        }
      }
      
      // 保存封面帧
      final coverFramePath = '${tempDir.path}/puzzle_frame_${timestamp}_cover.jpg';
      await _stitchImages(coverCellFrames, coverFramePath);
      frameImagePaths.add(coverFramePath);
      
      // 🔥 生成剩余的动画帧（从第1帧开始到第29帧）
      for (int frameIdx = 1; frameIdx < kTotalFrames; frameIdx++) {
        // 为每个 Live Photo 获取当前时间点的正确帧
        final cellFrames = <Uint8List>[];
        
        for (int i = 0; i < _selectedPhotos.length; i++) {
          final frames = _videoFrames[i];
          if (frames != null && frames.isNotEmpty) {
            // 根据时长决定帧索引（实现定格效果）
            final progress = frameIdx / (kTotalFrames - 1);
            final currentTimeMs = progress * _maxDurationMs;
            final videoDurationMs = _videoDurations[i] ?? 2000;
            
            if (currentTimeMs >= videoDurationMs) {
              // 超过时长，定格到封面
              final coverFrame = _coverFrames[i];
              if (coverFrame == null) {
                // 使用缩略图（已经是1200x1200高质量）
                if (_photoThumbnails[i] != null) {
                  cellFrames.add(_photoThumbnails[i]!);
                }
              } else {
                // 使用指定的视频帧
                cellFrames.add(frames[coverFrame.clamp(0, frames.length - 1)]);
              }
            } else {
              // 正常播放
              final videoProgress = (currentTimeMs / videoDurationMs).clamp(0.0, 1.0);
              final cellFrameIndex = (videoProgress * (frames.length - 1)).round().clamp(0, frames.length - 1);
              cellFrames.add(frames[cellFrameIndex]);
            }
          } else if (_photoThumbnails[i] != null) {
            cellFrames.add(_photoThumbnails[i]!);
          }
        }
        
        // 拼接图片
        final framePath = '${tempDir.path}/puzzle_frame_${timestamp}_$frameIdx.jpg';
        await _stitchImages(cellFrames, framePath);
        frameImagePaths.add(framePath);
        
        if (mounted && frameIdx % 5 == 0) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('生成中... ${(frameIdx / kTotalFrames * 100).toInt()}%'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFFFF4D7D),
            ),
          );
        }
      }
      
      // 3. 调用原生方法创建 Live Photo
      // 🔥 封面帧始终是第0帧（包含所有格子的原始封面或设置的封面）
      final coverIndex = 0;
      debugPrint('📸 整个拼图的封面帧索引: $coverIndex');
      final success = await LivePhotoBridge.createLivePhoto(frameImagePaths, coverIndex);
      
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Live Photo 保存成功！'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('保存失败，请重试'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      
      // 4. 清理临时文件
      for (final path in frameImagePaths) {
        try {
          await File(path).delete();
        } catch (e) {
          debugPrint('清理临时文件失败: $e');
        }
      }
      
    } catch (e) {
      debugPrint('保存拼图失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🔥 拼接多张图片为一张竖向长图（高清版本）
  Future<void> _stitchImages(List<Uint8List> imageDataList, String outputPath) async {
    if (imageDataList.isEmpty) return;
    
    // 🔥 解码所有图片，保持原始分辨率
    final images = <ui.Image>[];
    for (final imageData in imageDataList) {
      // 不限制分辨率，保持原始大小
      final codec = await ui.instantiateImageCodec(
        imageData,
        targetWidth: null, // 不缩放
        targetHeight: null, // 不缩放
      );
      final frame = await codec.getNextFrame();
      images.add(frame.image);
    }
    
    // 计算拼接后的总高度和统一宽度
    int maxWidth = 0;
    int totalHeight = 0;
    
    for (final image in images) {
      if (image.width > maxWidth) {
        maxWidth = image.width;
      }
    }
    
    // 🔥 限制最大宽度，避免图片过大
    const int MAX_WIDTH = 1200;
    if (maxWidth > MAX_WIDTH) {
      debugPrint('⚠️ 图片宽度 $maxWidth 超过限制，缩放到 $MAX_WIDTH');
      maxWidth = MAX_WIDTH;
    }
    
    // 计算每张图片按统一宽度缩放后的高度
    for (final image in images) {
      final aspectRatio = image.height / image.width;
      final scaledHeight = (maxWidth * aspectRatio).round();
      totalHeight += scaledHeight;
    }
    
    debugPrint('🖼️ 拼接图片尺寸: ${maxWidth}x$totalHeight');
    
    // 创建画布（高质量）
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..filterQuality = FilterQuality.high; // 🔥 使用高质量过滤
    
    int currentY = 0;
    
    // 绘制每张图片
    for (final image in images) {
      final aspectRatio = image.height / image.width;
      final scaledHeight = (maxWidth * aspectRatio).round();
      
      final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      final dstRect = Rect.fromLTWH(0, currentY.toDouble(), maxWidth.toDouble(), scaledHeight.toDouble());
      
      canvas.drawImageRect(image, srcRect, dstRect, paint);
      currentY += scaledHeight;
    }
    
    // 转换为图片（保持原始分辨率）
    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(maxWidth, totalHeight);
    final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();
    
    // 保存到文件
    await File(outputPath).writeAsBytes(pngBytes);
    
    debugPrint('✅ 拼接完成: ${(pngBytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
    
    // 清理资源
    for (final image in images) {
      image.dispose();
    }
    finalImage.dispose();
  }

  Uint8List? _getCurrentFrameImage() {
    if (_selectedCellIndex >= _selectedPhotos.length) return null;
    
    final frames = _videoFrames[_selectedCellIndex];
    if (frames == null || frames.isEmpty) {
      return _photoThumbnails[_selectedCellIndex];
    }
    
    final frameIndex = _selectedFrames[_selectedCellIndex] ?? 0;
    
    // 🔥 如果 frameIndex 是 -1，表示使用原始封面
    if (frameIndex == -1) {
      return _photoThumbnails[_selectedCellIndex];
    }
    
    if (frameIndex >= 0 && frameIndex < frames.length) {
      return frames[frameIndex];
    }
    
    return _photoThumbnails[_selectedCellIndex];
  }

  Map<int, Uint8List?> _getCellImages() {
    final cellImages = <int, Uint8List?>{};
    
    for (int i = 0; i < _selectedPhotos.length; i++) {
      final frames = _videoFrames[i];
      if (frames != null && frames.isNotEmpty) {
        if (_isPlayingLivePuzzle && _animation != null) {
          // 🔥 播放时：根据该 Live Photo 的时长决定是否定格
          final progress = _animation!.value.clamp(0.0, 1.0);
          final currentTimeMs = progress * _maxDurationMs;
          final videoDurationMs = _videoDurations[i] ?? 2000;
          
          if (currentTimeMs >= videoDurationMs) {
            // 🔥 当前时间已超过该视频时长，定格到封面
            final coverFrame = _coverFrames[i];
            if (coverFrame == null) {
              // 使用原始封面（缩略图）
              cellImages[i] = _photoThumbnails[i];
            } else {
              // 使用指定的视频帧
              cellImages[i] = frames[coverFrame.clamp(0, frames.length - 1)];
            }
          } else {
            // 🔥 还在播放时间内，正常播放
            final videoProgress = (currentTimeMs / videoDurationMs).clamp(0.0, 1.0);
            final frameIndex = (videoProgress * (frames.length - 1)).round().clamp(0, frames.length - 1);
            cellImages[i] = frames[frameIndex];
          }
        } else {
          // 静态显示选中的帧
          final frameIndex = _selectedFrames[i] ?? 0;
          if (frameIndex == -1) {
            // -1 表示显示原始封面
            cellImages[i] = _photoThumbnails[i];
          } else {
            cellImages[i] = frames[frameIndex.clamp(0, frames.length - 1)];
          }
        }
      } else {
        cellImages[i] = _photoThumbnails[i];
      }
    }
    
    return cellImages;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: Column(
        children: [
          // 头部
          EditorHeaderWidget(
            onBack: () => Navigator.pop(context),
            onDone: _savePuzzleToGallery,
          ),

          // 主内容区域
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // 🔥 LIVE 播放按钮 - 紧凑设计
                  if (_selectedPhotos.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: 200, // 🔥 固定宽度，不要太宽
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: _playLivePuzzle,
                          icon: Icon(
                            _isPlayingLivePuzzle ? Icons.pause : Icons.play_arrow,
                            size: 18,
                          ),
                          label: Text(
                            _isPlayingLivePuzzle ? '播放中...' : 'LIVE',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isPlayingLivePuzzle
                                ? Colors.grey.shade400
                                : const Color(0xFFFF4D7D),
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // 🔥 拼图预览
                  Builder(
                    builder: (context) {
                      // 🔥 播放时使用 AnimatedBuilder，静态时直接显示
                      if (_isPlayingLivePuzzle && _animation != null) {
                        return AnimatedBuilder(
                          animation: _animation!,
                          builder: (context, child) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: PuzzleGridWidget(
                                selectedCellIndex: _selectedCellIndex,
                                cellImages: _getCellImages(),
                                photoCount: _selectedPhotos.length,
                                onCellTap: (index) async {},
                              ),
                            );
                          },
                        );
                      } else {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: PuzzleGridWidget(
                            selectedCellIndex: _selectedCellIndex,
                            cellImages: _getCellImages(),
                            photoCount: _selectedPhotos.length,
                            onCellTap: (index) async {
                              if (_isPlayingLivePuzzle) return;
                              
                              setState(() {
                                _selectedCellIndex = index;
                                // 🔥 如果当前帧是 -1（原始封面），切换到帧选择器时设为 0
                                if (_selectedFrames[index] == -1) {
                                  _selectedFrames[index] = 0;
                                }
                              });
                              
                              if (!_videoFrames.containsKey(index)) {
                                await _extractVideoFrames(index);
                              }
                            },
                          ),
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 32),

                  // 帧选择器
                  if (_selectedCellIndex < _selectedPhotos.length)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _videoControllers[_selectedCellIndex] != null &&
                            _videoControllers[_selectedCellIndex]!.value.isInitialized
                          ? VideoFrameSelectorWidget(
                              videoController: _videoControllers[_selectedCellIndex]!,
                              isCover: _coverFrames[_selectedCellIndex] != null,
                              onSetCover: () async {
                                // 🔥 截取当前视频帧
                                final frameData = await _captureVideoFrame(_selectedCellIndex);
                                
                                if (frameData != null) {
                                  final controller = _videoControllers[_selectedCellIndex]!;
                                  final timeMs = controller.value.position.inMilliseconds;
                                  
                                  debugPrint('📌 设置封面: 格子 $_selectedCellIndex, 时间 ${timeMs}ms');
                                  
                                  setState(() {
                                    _coverFrames[_selectedCellIndex] = frameData;
                                    _coverFrameTime[_selectedCellIndex] = timeMs;
                                    _currentDisplayImages[_selectedCellIndex] = frameData;
                                  });
                                  
                                  // 显示提示
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '已设置为封面 (格子 ${_selectedCellIndex + 1}, ${(timeMs / 1000).toStringAsFixed(2)}s)',
                                        ),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: const Color(0xFFFF4D7D),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('截取帧失败，请重试'),
                                        duration: Duration(seconds: 2),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                            )
                          : Container(
                              height: 200,
                              alignment: Alignment.center,
                              child: const Text('正在加载视频...'),
                            ),
                    ),

                  const SizedBox(height: 24),

                  // 功能按钮
                  const FeatureButtonsWidget(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
