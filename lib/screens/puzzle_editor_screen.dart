import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_puzzle/providers/photo_provider.dart';
import 'package:live_puzzle/providers/puzzle_history_provider.dart';
import 'package:live_puzzle/models/puzzle_history.dart';
import 'package:live_puzzle/screens/completion_screen.dart';
import 'package:live_puzzle/services/live_photo_manager.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:live_photo_bridge/live_photo_bridge.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

// 🔥 新增：数据模型和引擎
import 'package:live_puzzle/models/canvas_config.dart';
import 'package:live_puzzle/models/layout_template.dart';
import 'package:live_puzzle/models/image_block.dart';
import 'package:live_puzzle/services/layout_engine.dart';
import 'package:live_puzzle/models/image_transform.dart';

// 导入拆分的组件
import 'puzzle_editor/editor_header_widget.dart';
import 'puzzle_editor/puzzle_grid_widget.dart';
import 'puzzle_editor/video_frame_selector_widget.dart';
import 'puzzle_editor/image_action_menu.dart';
import 'puzzle_editor/dynamic_toolbar.dart';
import 'puzzle_editor/layout_selection_panel.dart';
import 'puzzle_editor/data_driven_canvas.dart';
import 'package:live_puzzle/widgets/export_progress_dialog.dart';
import 'package:live_puzzle/l10n/app_localizations.dart';

/// 拼图编辑器页面 - Seamless Puzzle风格
class PuzzleEditorScreen extends ConsumerStatefulWidget {
  const PuzzleEditorScreen({super.key});

  @override
  ConsumerState<PuzzleEditorScreen> createState() =>
      _PuzzleEditorScreenState();
}

class _PuzzleEditorScreenState extends ConsumerState<PuzzleEditorScreen> 
    with TickerProviderStateMixin {
  
  // 🔥 基础状态
  static const int kTotalFrames = 30;
  int _selectedCellIndex = -1; // -1 表示未选中任何图片
  List<AssetEntity> _selectedPhotos = [];
  final Map<int, Uint8List?> _photoThumbnails = {};
  
  // 🔥 新增：编辑状态管理
  EditorState _editorState = EditorState.global; // 当前编辑状态
  GlobalTool? _selectedGlobalTool; // 选中的全局工具
  SingleTool? _selectedSingleTool; // 选中的单图工具
  
  // 🔥 新的数据驱动布局系统
  CanvasConfig _canvasConfig = CanvasConfig.fromRatio('1:1'); // 画布配置
  LayoutTemplate? _currentLayout; // 当前布局模板
  List<ImageBlock> _imageBlocks = []; // 图片块列表（使用相对坐标0-1）
  String? _selectedBlockId; // 选中的图片块ID
  bool _useNewCanvas = true; // 切换开关，true 使用新画布
  
  // 🔥 布局管理（旧系统，废弃）
  final Map<int, ImageTransform> _imageTransforms = {};
  
  // 🔥 旧的frame-by-frame方式(保留用于播放和保存)
  final Map<int, int> _selectedFrames = {}; // 当前选中的帧索引
  final Map<int, List<Uint8List>> _videoFrames = {}; // 提取的所有帧
  
  // 🔥 视频播放器相关(新的video-player方式，用于交互选择)
  final Map<int, VideoPlayerController?> _videoControllers = {};
  final Map<int, String?> _videoPaths = {}; // 存储视频文件路径
  final Map<int, int> _videoDurations = {}; // 存储视频时长（毫秒）
  int _maxDurationMs = 2000;
  
  // 🔥 封面帧：存储截取的封面图片
  final Map<int, Uint8List?> _coverFrames = {}; // null 表示使用原始封面
  
  // 🔥 导出进度控制器
  ExportProgressController? _exportProgressController;
  final Map<int, int?> _coverFrameTime = {}; // 存储封面帧的时间点（毫秒）
  
  // 🔥 Live 拼图播放
  AnimationController? _animationController;
  Animation<double>? _animation;
  bool _isPlayingLivePuzzle = false;
  
  // 🔥 当前显示的图片（用于网格显示）
  final Map<int, Uint8List?> _currentDisplayImages = {};
  
  // 🔥 帧编辑：进入帧选择时保存原始图片，取消时恢复
  final Map<int, Uint8List?> _preEditImageData = {};
  Timer? _frameExtractTimer; // 节流定时器
  bool _isExtractingFrame = false; // 防止重入

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
    
    // 🔥 监听动画帧更新 → 实时更新新画布中的图片
    _animationController!.addListener(_onAnimationTick);

    // 🔥 监听动画完成
    _animationController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          debugPrint('🎬 动画完成，恢复封面');
          setState(() {
            _isPlayingLivePuzzle = false;
            // 🔥 恢复到各自的封面
            for (int i = 0; i < _selectedPhotos.length; i++) {
              final coverFrameData = _coverFrames[i];
              if (coverFrameData != null) {
                _currentDisplayImages[i] = coverFrameData;
              } else {
                _currentDisplayImages[i] = _photoThumbnails[i];
              }
            }
            // 🔥 同步恢复新画布 imageBlocks
            _restoreImageBlocksToCovers();
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
    _frameExtractTimer?.cancel();
    _animationController?.dispose();
    _exportProgressController?.dispose();
    // 🔥 释放所有视频播放器
    for (final controller in _videoControllers.values) {
      controller?.dispose();
    }
    super.dispose();
  }

  /// 根据图片数量确定初始布局（1张=1:1, 2张=3:4上下, 3张=9:16上下, 4-9张=长图纵向）
  (CanvasConfig, LayoutTemplate) _getInitialLayout(int photoCount) {
    if (photoCount == 1) {
      return (
        CanvasConfig.fromRatio('1:1'),
        LayoutTemplate.presetLayouts.firstWhere((t) => t.id == 'single')
      );
    } else if (photoCount == 2) {
      return (
        CanvasConfig.fromRatio('3:4'),
        LayoutTemplate.presetLayouts.firstWhere((t) => t.id == 'grid_2x1') // 上下平分
      );
    } else if (photoCount == 3) {
      return (
        CanvasConfig.fromRatio('9:16'),
        LayoutTemplate.presetLayouts.firstWhere((t) => t.id == 'grid_3x1') // 三行一列
      );
    } else {
      // 4-9张：长图纵向拼接
      return (
        CanvasConfig.fromRatio('1:1'), // 占位，会被重新计算
        LayoutTemplate.getLongImageLayouts(photoCount).firstWhere((t) => t.id == 'long_vertical')
      );
    }
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
      
      if (mounted && selectedAssets.isNotEmpty) {
        // 🔥 立即确定初始布局
        final (canvas, template) = _getInitialLayout(selectedAssets.length);
        
        setState(() {
          _selectedPhotos = selectedAssets;
          _canvasConfig = canvas;
          _currentLayout = template;
          
          // 初始化状态
          for (int i = 0; i < selectedAssets.length; i++) {
            if (!_selectedFrames.containsKey(i)) {
              _selectedFrames[i] = 0;
            }
            if (!_coverFrames.containsKey(i)) {
              _coverFrames[i] = null;
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
          _animationController!.addListener(_onAnimationTick);
          _animationController!.addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              if (mounted) {
                setState(() {
                  _isPlayingLivePuzzle = false;
                  // 🔥 恢复到各自的封面
                  for (int i = 0; i < _selectedPhotos.length; i++) {
                    final coverFrameData = _coverFrames[i];
                    if (coverFrameData != null) {
                      _currentDisplayImages[i] = coverFrameData;
                    } else {
                      _currentDisplayImages[i] = _photoThumbnails[i];
                    }
                  }
                  _restoreImageBlocksToCovers();
                });
                _animationController?.reset();
              }
            }
          });
        }

        // 🔥 加载缩略图并立即应用布局
        final List<Uint8List> loadedThumbnails = [];
        for (int i = 0; i < _selectedPhotos.length; i++) {
          try {
            final thumbnail = await _selectedPhotos[i].thumbnailDataWithSize(
              const ThumbnailSize(2000, 2000),
              quality: 95,
            );
            if (thumbnail != null) {
              loadedThumbnails.add(thumbnail);
              if (mounted) {
                setState(() {
                  _photoThumbnails[i] = thumbnail;
                });
              }
            }
          } catch (e) {
            debugPrint('Error loading thumbnail $i: $e');
          }
        }
        
        // 🔥 应用初始布局（无延迟，立即执行）
        if (mounted && loadedThumbnails.isNotEmpty && _currentLayout != null) {
          _applyLayout(_canvasConfig, _currentLayout!);
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

  // 🔥 交换两张图片的位置
  void _reorderImages(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return;
    if (fromIndex >= _selectedPhotos.length || toIndex >= _selectedPhotos.length) return;
    
    debugPrint('🔄 交换图片: $fromIndex ↔️ $toIndex');
    
    setState(() {
      // 交换 AssetEntity
      final tempPhoto = _selectedPhotos[fromIndex];
      _selectedPhotos[fromIndex] = _selectedPhotos[toIndex];
      _selectedPhotos[toIndex] = tempPhoto;
      
      // 交换缩略图
      final tempThumbnail = _photoThumbnails[fromIndex];
      _photoThumbnails[fromIndex] = _photoThumbnails[toIndex];
      _photoThumbnails[toIndex] = tempThumbnail;
      
      // 交换封面帧
      final tempCoverFrame = _coverFrames[fromIndex];
      _coverFrames[fromIndex] = _coverFrames[toIndex];
      _coverFrames[toIndex] = tempCoverFrame;
      
      // 交换封面帧时间
      final tempCoverTime = _coverFrameTime[fromIndex];
      _coverFrameTime[fromIndex] = _coverFrameTime[toIndex];
      _coverFrameTime[toIndex] = tempCoverTime;
      
      // 交换视频帧（如果已提取）- 处理 null 安全
      final tempVideoFrames = _videoFrames[fromIndex];
      final toVideoFrames = _videoFrames[toIndex];
      
      if (toVideoFrames != null) {
        _videoFrames[fromIndex] = toVideoFrames;
      } else {
        _videoFrames.remove(fromIndex);
      }
      
      if (tempVideoFrames != null) {
        _videoFrames[toIndex] = tempVideoFrames;
      } else {
        _videoFrames.remove(toIndex);
      }
      
      // 交换视频时长 - 处理 null 安全
      final tempDuration = _videoDurations[fromIndex];
      final toDuration = _videoDurations[toIndex];
      
      if (toDuration != null) {
        _videoDurations[fromIndex] = toDuration;
      } else {
        _videoDurations.remove(fromIndex);
      }
      
      if (tempDuration != null) {
        _videoDurations[toIndex] = tempDuration;
      } else {
        _videoDurations.remove(toIndex);
      }
      
      // 交换视频控制器
      final tempController = _videoControllers[fromIndex];
      _videoControllers[fromIndex] = _videoControllers[toIndex];
      _videoControllers[toIndex] = tempController;
      
      // 交换视频路径
      final tempPath = _videoPaths[fromIndex];
      _videoPaths[fromIndex] = _videoPaths[toIndex];
      _videoPaths[toIndex] = tempPath;
      
      // 交换选中帧索引 - 处理 null 安全
      final tempSelectedFrame = _selectedFrames[fromIndex];
      final toSelectedFrame = _selectedFrames[toIndex];
      
      if (toSelectedFrame != null) {
        _selectedFrames[fromIndex] = toSelectedFrame;
      } else {
        _selectedFrames.remove(fromIndex);
      }
      
      if (tempSelectedFrame != null) {
        _selectedFrames[toIndex] = tempSelectedFrame;
      } else {
        _selectedFrames.remove(toIndex);
      }
      
      // 交换当前显示图片
      final tempDisplayImage = _currentDisplayImages[fromIndex];
      _currentDisplayImages[fromIndex] = _currentDisplayImages[toIndex];
      _currentDisplayImages[toIndex] = tempDisplayImage;
      
      // 如果交换的是当前选中的图片，更新选中索引
      if (_selectedCellIndex == fromIndex) {
        _selectedCellIndex = toIndex;
      } else if (_selectedCellIndex == toIndex) {
        _selectedCellIndex = fromIndex;
      }
    });
  }

  // 🔥 状态切换逻辑
  void _handleImageTap(int index) {
    setState(() {
      _selectedCellIndex = index;
      _editorState = EditorState.single; // 切换到单图编辑状态
      _selectedSingleTool = null; // 清空工具选择
    });
    
    if (!_videoFrames.containsKey(index)) {
      _extractVideoFrames(index);
    }
  }

  void _handleCanvasTap() {
    // 取消选中时恢复原始图片（如果有未确认的帧编辑）
    _revertFrameEdit();
    setState(() {
      _selectedCellIndex = -1;
      _selectedBlockId = null;
      _editorState = EditorState.global;
      _selectedGlobalTool = null;
    });
  }

  /// 恢复帧编辑前的图片（取消时调用）
  void _revertFrameEdit() {
    _frameExtractTimer?.cancel();
    if (_selectedCellIndex >= 0 && _preEditImageData.containsKey(_selectedCellIndex)) {
      final originalData = _preEditImageData[_selectedCellIndex];
      if (originalData != null && _selectedCellIndex < _imageBlocks.length) {
        setState(() {
          _imageBlocks[_selectedCellIndex] = _imageBlocks[_selectedCellIndex].copyWith(
            imageData: originalData,
          );
        });
      }
      _preEditImageData.remove(_selectedCellIndex);
    }
  }

  /// 真正的节流（throttle）：滑动过程中持续提取帧，不等松手
  int? _pendingFrameTimeMs; // 排队等待的帧时间
  
  void _throttledExtractFrame(int cellIndex, int timeMs) {
    if (_isExtractingFrame) {
      // 正在提取中 → 记录最新请求，等当前完成后自动处理
      _pendingFrameTimeMs = timeMs;
      return;
    }
    // 立即开始提取
    _doExtractFrame(cellIndex, timeMs);
  }
  
  Future<void> _doExtractFrame(int cellIndex, int timeMs) async {
    if (!mounted || cellIndex < 0 || cellIndex >= _imageBlocks.length) return;
    _isExtractingFrame = true;
    _pendingFrameTimeMs = null;
    
    try {
      final frameData = await _captureVideoFrame(cellIndex);
      if (frameData != null && mounted && cellIndex < _imageBlocks.length) {
        setState(() {
          _imageBlocks[cellIndex] = _imageBlocks[cellIndex].copyWith(
            imageData: frameData,
          );
        });
      }
    } finally {
      _isExtractingFrame = false;
      // 如果有排队的请求，立即处理最新的那个
      if (_pendingFrameTimeMs != null && mounted) {
        final pending = _pendingFrameTimeMs!;
        _pendingFrameTimeMs = null;
        _doExtractFrame(cellIndex, pending);
      }
    }
  }

  // 🔥 全局工具处理
  void _handleGlobalTool(GlobalTool tool) {
    setState(() {
      _selectedGlobalTool = _selectedGlobalTool == tool ? null : tool;
    });
    
    switch (tool) {
      case GlobalTool.layout:
        // 布局工具已经通过底部面板展示
        break;
      case GlobalTool.filter:
        // TODO: 显示滤镜面板
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('滤镜功能开发中')),
        );
        break;
      case GlobalTool.adjust:
        // TODO: 显示调节面板
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('调节功能开发中')),
        );
        break;
      case GlobalTool.text:
        // TODO: 添加文字
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文字功能开发中')),
        );
        break;
    }
  }

  // 🔥 应用布局（使用新的数据驱动系统）
  void _applyLayout(CanvasConfig canvas, LayoutTemplate template) async {
    if (_selectedPhotos.isEmpty) return;
    
    setState(() {
      _canvasConfig = canvas;
      _currentLayout = template;
    });
    
    // 收集图片数据
    final List<Uint8List> images = [];
    for (int i = 0; i < _selectedPhotos.length; i++) {
      final imageData = _coverFrames[i] ?? _photoThumbnails[i];
      if (imageData != null) {
        images.add(imageData);
      }
    }
    
    if (images.isEmpty) return;
    
    // 🔥 检查是否为长图拼接
    final isLongImage = template.id == 'long_horizontal' || template.id == 'long_vertical';
    CanvasConfig finalCanvas = canvas;
    
    if (isLongImage) {
      // 🔥 长图拼接：根据实际图片尺寸计算画布
      finalCanvas = await _calculateLongImageCanvas(template, images);
    }
    
    // 🔥 预解码图片获取宽高比
    final aspectRatios = <double>[];
    for (final imgData in images) {
      try {
        final codec = await ui.instantiateImageCodec(imgData);
        final frame = await codec.getNextFrame();
        aspectRatios.add(frame.image.width / frame.image.height);
        frame.image.dispose();
      } catch (_) {
        aspectRatios.add(1.0); // 默认正方形
      }
    }

    setState(() {
      _useNewCanvas = true;
      _canvasConfig = finalCanvas;
      _currentLayout = template;
      
      _imageBlocks = LayoutEngine.calculateLayout(
        canvas: finalCanvas,
        template: template,
        images: images,
        spacing: 0.0,
      );
      
      // 🔥 为每个 block 设置图片宽高比
      for (int i = 0; i < _imageBlocks.length && i < aspectRatios.length; i++) {
        _imageBlocks[i] = _imageBlocks[i].copyWith(imageAspectRatio: aspectRatios[i]);
      }
      
      _selectedBlockId = null;
      _editorState = EditorState.global;
    });
    
  }
  
  // 🔥 计算长图拼接的画布尺寸（基于实际图片）
  Future<CanvasConfig> _calculateLongImageCanvas(
    LayoutTemplate template,
    List<Uint8List> images,
  ) async {
    if (images.isEmpty) {
      return CanvasConfig.fromRatio('1:1');
    }
    
    final isHorizontal = template.id == 'long_horizontal';
    
    // 解码所有图片获取实际尺寸
    final imageSizes = <Size>[];
    for (final imageData in images) {
      try {
        final codec = await ui.instantiateImageCodec(imageData);
        final frame = await codec.getNextFrame();
        final imgWidth = frame.image.width.toDouble();
        final imgHeight = frame.image.height.toDouble();
        imageSizes.add(Size(imgWidth, imgHeight));
        debugPrint('🖼️ Image size: ${imgWidth}x${imgHeight}');
        frame.image.dispose();
        codec.dispose();
      } catch (e) {
        // 解码失败，使用默认尺寸
        debugPrint('⚠️ Error decoding image: $e');
        imageSizes.add(const Size(1080, 1920));
      }
    }
    
    if (isHorizontal) {
      // 🔥 横向拼接：统一高度为最大高度，按比例调整宽度
      final maxHeight = imageSizes.map((s) => s.height).reduce(math.max);
      
      // 计算所有图片按统一高度缩放后的总宽度
      double totalWidth = 0;
      for (final size in imageSizes) {
        final scaledWidth = (size.width / size.height) * maxHeight;
        totalWidth += scaledWidth;
      }
      
      debugPrint('📐 横向拼接: ${totalWidth.toInt()}x${maxHeight.toInt()}');
      
      return CanvasConfig(
        width: totalWidth,
        height: maxHeight,
        ratio: '${totalWidth.toInt()}:${maxHeight.toInt()}',
        type: CanvasRatioType.custom,
      );
    } else {
      // 🔥 纵向拼接：统一宽度为最大宽度，按比例调整高度
      final maxWidth = imageSizes.map((s) => s.width).reduce(math.max);
      
      // 计算所有图片按统一宽度缩放后的总高度
      double totalHeight = 0;
      for (final size in imageSizes) {
        final scaledHeight = (size.height / size.width) * maxWidth;
        totalHeight += scaledHeight;
      }
      
      debugPrint('📐 纵向拼接: ${maxWidth.toInt()}x${totalHeight.toInt()}');
      
      return CanvasConfig(
        width: maxWidth,
        height: totalHeight,
        ratio: '${maxWidth.toInt()}:${totalHeight.toInt()}',
        type: CanvasRatioType.custom,
      );
    }
  }

  // 🔥 单图工具处理
  void _handleSingleTool(SingleTool tool) {
    if (_selectedCellIndex < 0) return;
    
    setState(() {
      _selectedSingleTool = _selectedSingleTool == tool ? null : tool;
    });
    
    switch (tool) {
      case SingleTool.filter:
        // TODO: 显示滤镜面板（仅应用到选中图片）
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('单图滤镜功能开发中')),
        );
        break;
      case SingleTool.adjust:
        // TODO: 显示调节面板（仅应用到选中图片）
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('单图调节功能开发中')),
        );
        break;
      case SingleTool.replace:
        // TODO: 替换图片
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('替换图片功能开发中')),
        );
        break;
      case SingleTool.rotate:
        _rotateImage90();
        break;
      case SingleTool.flipH:
        _flipImageHorizontal();
        break;
      case SingleTool.flipV:
        _flipImageVertical();
        break;
    }
  }

  void _rotateImage90() {
    if (_selectedCellIndex < 0) return;
    setState(() {
      final transform = _imageTransforms[_selectedCellIndex] ?? ImageTransform();
      _imageTransforms[_selectedCellIndex] = transform.copyWith(
        rotation: transform.rotation + 1.5708, // 90度
      );
    });
  }

  void _flipImageHorizontal() {
    // TODO: 实现水平翻转
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('水平翻转功能开发中')),
    );
  }

  void _flipImageVertical() {
    // TODO: 实现垂直翻转
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('垂直翻转功能开发中')),
    );
  }

  // 🔥 关键帧操作
  // 🔥 新增：图片操作方法
  void _handleImageTransformChanged(int index, ImageTransform transform) {
    setState(() {
      _imageTransforms[index] = transform;
    });
  }

  void _handleImageLongPress(int index) {
    ImageActionMenu.show(
      context,
      onReplace: () {
        // TODO: 实现替换图片功能
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('替换图片功能开发中')),
        );
      },
      onDelete: () {
        _deleteImage(index);
      },
      onBringToFront: () {
        _bringImageToFront(index);
      },
      onSendToBack: () {
        _sendImageToBack(index);
      },
    );
  }

  void _deleteImage(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
      _photoThumbnails.remove(index);
      _coverFrames.remove(index);
      _coverFrameTime.remove(index);
      _videoFrames.remove(index);
      _videoDurations.remove(index);
      _videoControllers[index]?.dispose();
      _videoControllers.remove(index);
      _videoPaths.remove(index);
      _selectedFrames.remove(index);
      _currentDisplayImages.remove(index);
      _imageTransforms.remove(index);
      
      // 重新索引
      final newThumbnails = <int, Uint8List?>{};
      final newCoverFrames = <int, Uint8List?>{};
      final newCoverFrameTime = <int, int?>{};
      final newVideoFrames = <int, List<Uint8List>>{};
      final newVideoDurations = <int, int>{};
      final newVideoControllers = <int, VideoPlayerController?>{};
      final newVideoPaths = <int, String?>{};
      final newSelectedFrames = <int, int>{};
      final newDisplayImages = <int, Uint8List?>{};
      final newTransforms = <int, ImageTransform>{};
      
      for (int i = 0; i < _selectedPhotos.length; i++) {
        final oldIndex = i >= index ? i + 1 : i;
        if (_photoThumbnails.containsKey(oldIndex)) {
          newThumbnails[i] = _photoThumbnails[oldIndex];
        }
        if (_coverFrames.containsKey(oldIndex)) {
          newCoverFrames[i] = _coverFrames[oldIndex];
        }
        if (_coverFrameTime.containsKey(oldIndex)) {
          newCoverFrameTime[i] = _coverFrameTime[oldIndex];
        }
        if (_videoFrames.containsKey(oldIndex)) {
          newVideoFrames[i] = _videoFrames[oldIndex]!;
        }
        if (_videoDurations.containsKey(oldIndex)) {
          newVideoDurations[i] = _videoDurations[oldIndex]!;
        }
        if (_videoControllers.containsKey(oldIndex)) {
          newVideoControllers[i] = _videoControllers[oldIndex];
        }
        if (_videoPaths.containsKey(oldIndex)) {
          newVideoPaths[i] = _videoPaths[oldIndex];
        }
        if (_selectedFrames.containsKey(oldIndex)) {
          newSelectedFrames[i] = _selectedFrames[oldIndex]!;
        }
        if (_currentDisplayImages.containsKey(oldIndex)) {
          newDisplayImages[i] = _currentDisplayImages[oldIndex];
        }
        if (_imageTransforms.containsKey(oldIndex)) {
          newTransforms[i] = _imageTransforms[oldIndex]!;
        }
      }
      
      _photoThumbnails.clear();
      _photoThumbnails.addAll(newThumbnails);
      _coverFrames.clear();
      _coverFrames.addAll(newCoverFrames);
      _coverFrameTime.clear();
      _coverFrameTime.addAll(newCoverFrameTime);
      _videoFrames.clear();
      _videoFrames.addAll(newVideoFrames);
      _videoDurations.clear();
      _videoDurations.addAll(newVideoDurations);
      _videoControllers.clear();
      _videoControllers.addAll(newVideoControllers);
      _videoPaths.clear();
      _videoPaths.addAll(newVideoPaths);
      _selectedFrames.clear();
      _selectedFrames.addAll(newSelectedFrames);
      _currentDisplayImages.clear();
      _currentDisplayImages.addAll(newDisplayImages);
      _imageTransforms.clear();
      _imageTransforms.addAll(newTransforms);
      
      // 更新选中索引
      if (_selectedCellIndex == index) {
        _selectedCellIndex = -1;
      } else if (_selectedCellIndex > index) {
        _selectedCellIndex--;
      }
    });
  }

  void _bringImageToFront(int index) {
    setState(() {
      final maxZ = _imageTransforms.values.map((t) => t.zIndex).fold(0, (a, b) => a > b ? a : b);
      _imageTransforms[index] = _imageTransforms[index]!.copyWith(zIndex: maxZ + 1);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已置于顶层'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _sendImageToBack(int index) {
    setState(() {
      final minZ = _imageTransforms.values.map((t) => t.zIndex).fold(0, (a, b) => a < b ? a : b);
      _imageTransforms[index] = _imageTransforms[index]!.copyWith(zIndex: minZ - 1);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已置于底层'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _extractVideoFrames(int cellIndex) async {
    // 先初始化视频播放器（用于交互选择）
    await _initVideoPlayer(cellIndex);
    
    // 🔥 同时提取帧（用于播放和保存）
    if (_videoFrames.containsKey(cellIndex)) return; // 已提取
    
    final asset = _selectedPhotos[cellIndex];
    try {
      final isLive = await LivePhotoManager.isLivePhoto(asset);
      if (!isLive) return;
      
      // 🔥 获取视频路径
      final videoPath = _videoPaths[cellIndex];
      if (videoPath == null || videoPath.isEmpty) {
        debugPrint('⚠️ 视频路径为空，无法提取帧');
        return;
      }
      
      final videoDurationMs = _videoDurations[cellIndex] ?? 2000;
      debugPrint('🎞️ 开始提取 Live Photo 帧: $cellIndex, 时长: ${videoDurationMs}ms');
      
      // 🔥 均匀采样30帧，覆盖整个视频时长（从0到videoDurationMs）
      final frames = <Uint8List>[];
      for (int i = 0; i < kTotalFrames; i++) {
        final progress = i / (kTotalFrames - 1);
        final timeMs = (progress * videoDurationMs).round();
        
        try {
          final framePath = await LivePhotoBridge.extractFrame(videoPath, timeMs);
          if (framePath != null) {
            final file = File(framePath);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              frames.add(bytes);
              await file.delete();
            }
          }
        } catch (e) {
          debugPrint('⚠️ 提取帧 $i (${timeMs}ms) 失败: $e');
        }
      }
      
      if (frames.isNotEmpty) {
        setState(() {
          _videoFrames[cellIndex] = frames;
        });
        debugPrint('✅ Live Photo $cellIndex 提取了 ${frames.length} 帧');
      }
    } catch (e) {
      debugPrint('❌ 提取 Live Photo 帧失败: $e');
    }
  }

  // 🔥 动画帧回调：实时更新新画布中 imageBlocks 的图片
  void _onAnimationTick() {
    if (!_isPlayingLivePuzzle || !_useNewCanvas) return;
    if (_animation == null) return;

    final progress = _animation!.value.clamp(0.0, 1.0);
    final currentTimeMs = progress * _maxDurationMs;

    bool changed = false;
    for (int i = 0; i < _imageBlocks.length && i < _selectedPhotos.length; i++) {
      final frames = _videoFrames[i];
      Uint8List? newData;

      if (frames != null && frames.isNotEmpty) {
        final videoDurationMs = _videoDurations[i] ?? 2000;
        if (currentTimeMs >= videoDurationMs) {
          // 超过该视频时长 → 定格到封面
          newData = _coverFrames[i] ?? _photoThumbnails[i];
        } else {
          // 正常播放
          final videoProgress = (currentTimeMs / videoDurationMs).clamp(0.0, 1.0);
          final frameIndex = (videoProgress * (frames.length - 1)).round().clamp(0, frames.length - 1);
          newData = frames[frameIndex];
        }
      } else {
        newData = _coverFrames[i] ?? _photoThumbnails[i];
      }

      if (newData != null && newData != _imageBlocks[i].imageData) {
        _imageBlocks[i] = _imageBlocks[i].copyWith(imageData: newData);
        changed = true;
      }
    }

    if (changed && mounted) setState(() {});
  }

  // 🔥 恢复 imageBlocks 到封面帧
  void _restoreImageBlocksToCovers() {
    for (int i = 0; i < _imageBlocks.length && i < _selectedPhotos.length; i++) {
      final coverData = _coverFrames[i] ?? _photoThumbnails[i];
      if (coverData != null) {
        _imageBlocks[i] = _imageBlocks[i].copyWith(imageData: coverData);
      }
    }
  }

  Future<void> _playLivePuzzle() async {
    if (_animationController == null || _animation == null) return;
    
    if (_isPlayingLivePuzzle) {
      // 🔥 停止播放，恢复到各自的封面帧
      debugPrint('⏸️ 停止播放 Live Puzzle');
      setState(() {
        _isPlayingLivePuzzle = false;
        _restoreImageBlocksToCovers();
      });
      _animationController?.stop();
      _animationController?.reset();
      return;
    }
    
    // 确保所有照片的帧都已加载
    bool needsLoading = false;
    for (int i = 0; i < _selectedPhotos.length; i++) {
      if (!_videoFrames.containsKey(i)) {
        needsLoading = true;
        debugPrint('⚠️ 格子 $i 的视频帧尚未提取');
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
      
      debugPrint('🎞️ 开始提取所有视频帧...');
      await Future.wait(
        List.generate(_selectedPhotos.length, (i) {
          if (!_videoFrames.containsKey(i)) {
            return _extractVideoFrames(i);
          }
          return Future.value();
        }),
      );
      
      // 检查提取是否成功
      int successCount = 0;
      for (int i = 0; i < _selectedPhotos.length; i++) {
        if (_videoFrames.containsKey(i) && _videoFrames[i]!.isNotEmpty) {
          successCount++;
        }
      }
      debugPrint('✅ 提取完成: $successCount/${_selectedPhotos.length} 个视频');
      
      if (successCount == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('视频帧提取失败，无法播放'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }
    
    debugPrint('▶️ 开始播放 Live Puzzle');
    setState(() {
      _isPlayingLivePuzzle = true;
    });
    
    _animationController?.forward(from: 0.0);
  }

  // 🔥 保存拼图到图库（Live Photo 格式）
  Future<void> _savePuzzleToGallery() async {
    if (_selectedPhotos.isEmpty) return;
    
    final l10n = AppLocalizations.of(context)!;
    
    try {
      // 显示初始进度对话框
      if (mounted) {
        _exportProgressController = ExportProgressDialog.show(context);
        _exportProgressController!.update(
          progress: 0.0,
          message: l10n.exportingLivePhoto,
          subMessage: l10n.preparingFrames,
        );
      }
      
      // 1. 确保所有帧都已加载
      for (int i = 0; i < _selectedPhotos.length; i++) {
        if (!_videoFrames.containsKey(i)) {
          await _extractVideoFrames(i);
        }
        // 更新准备进度
        if (mounted && _exportProgressController != null) {
          final prepareProgress = (i + 1) / _selectedPhotos.length * 0.1; // 占10%
          _exportProgressController!.update(
            progress: prepareProgress,
            message: l10n.exportingLivePhoto,
            subMessage: '${l10n.loadingFrames} ${i + 1}/${_selectedPhotos.length}',
          );
        }
      }
      
      // 2. 为每一帧创建拼接图片
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final frameImagePaths = <String>[];
      final useLayout = _useNewCanvas && _imageBlocks.isNotEmpty;

      // 🔥 预计算输出尺寸（布局模式），提高到 2400px 保证清晰
      int outW = 0, outH = 0;
      if (useLayout) {
        final cw = _canvasConfig.width;
        final ch = _canvasConfig.height;
        const int maxSide = 2400;
        final sf = cw >= ch ? maxSide / cw : maxSide / ch;
        outW = (cw * sf).round();
        outH = (ch * sf).round();
      }

      // 🔥 预解码所有不变的图片（封面/缩略图），建立缓存
      final imageCache = <String, ui.Image>{}; // key = bytes hashCode
      Future<ui.Image> getCachedImage(Uint8List data) async {
        final key = '${identityHashCode(data)}';
        if (imageCache.containsKey(key)) return imageCache[key]!;
        final img = await _decodeImage(data);
        imageCache[key] = img;
        return img;
      }

      // 🔥 获取某一帧的每个格子的图片数据
      List<Uint8List> getFrameCellData(int frameIdx) {
        final cellFrames = <Uint8List>[];
        for (int i = 0; i < _selectedPhotos.length; i++) {
          if (frameIdx == 0) {
            // 封面帧
            final coverData = _coverFrames[i] ?? _photoThumbnails[i];
            if (coverData != null) cellFrames.add(coverData);
          } else {
            final frames = _videoFrames[i];
            if (frames != null && frames.isNotEmpty) {
              final progress = frameIdx / (kTotalFrames - 1);
              final currentTimeMs = progress * _maxDurationMs;
              final videoDurationMs = _videoDurations[i] ?? 2000;
              if (currentTimeMs >= videoDurationMs) {
                final coverData = _coverFrames[i] ?? _photoThumbnails[i];
                if (coverData != null) cellFrames.add(coverData);
              } else {
                final videoProgress = (currentTimeMs / videoDurationMs).clamp(0.0, 1.0);
                final fi = (videoProgress * (frames.length - 1)).round().clamp(0, frames.length - 1);
                cellFrames.add(frames[fi]);
              }
            } else if (_photoThumbnails[i] != null) {
              cellFrames.add(_photoThumbnails[i]!);
            }
          }
        }
        return cellFrames;
      }

      final sw = Stopwatch()..start();

      // 🔥 生成所有帧（占80%进度，10%-90%）
      for (int frameIdx = 0; frameIdx < kTotalFrames; frameIdx++) {
        final cellData = getFrameCellData(frameIdx);
        final framePath = '${tempDir.path}/puzzle_frame_${timestamp}_$frameIdx.jpg';

        if (useLayout) {
          // 解码当前帧图片（利用缓存避免重复解码）
          final decoded = <ui.Image>[];
          for (final data in cellData) {
            decoded.add(await getCachedImage(data));
          }
          await _renderLayoutFrameFast(decoded, outW, outH, framePath);
        } else {
          await _stitchImages(cellData, framePath);
        }
        frameImagePaths.add(framePath);

        // 更新进度（每帧更新）
        if (mounted && _exportProgressController != null) {
          final frameProgress = 0.1 + (frameIdx + 1) / kTotalFrames * 0.8; // 10%-90%
          _exportProgressController!.update(
            progress: frameProgress,
            message: l10n.exportingLivePhoto,
            subMessage: '${l10n.renderingFrames} ${frameIdx + 1}/$kTotalFrames',
          );
        }
      }

      debugPrint('⏱️ 全部 $kTotalFrames 帧渲染完成，耗时 ${sw.elapsedMilliseconds}ms');

      // 清理图片缓存
      for (final img in imageCache.values) {
        img.dispose();
      }
      imageCache.clear();
      
      // 3. 调用原生方法创建 Live Photo（占最后10%，90%-100%）
      if (mounted && _exportProgressController != null) {
        _exportProgressController!.update(
          progress: 0.9,
          message: l10n.exportingLivePhoto,
          subMessage: l10n.savingToAlbum,
        );
      }
      
      // 🔥 封面帧始终是第0帧（包含所有格子的原始封面或设置的封面）
      final coverIndex = 0;
      debugPrint('📸 整个拼图的封面帧索引: $coverIndex');
      final success = await LivePhotoBridge.createLivePhoto(frameImagePaths, coverIndex);
      
      if (mounted) {
        // 关闭进度对话框
        Navigator.of(context, rootNavigator: true).pop();
        _exportProgressController?.dispose();
        _exportProgressController = null;
        
        if (success) {
          // 🔥 读取第一帧图片作为拼接效果缩略图
          Uint8List? puzzleThumbnail;
          try {
            final firstFrameFile = File(frameImagePaths[0]);
            if (await firstFrameFile.exists()) {
              puzzleThumbnail = await firstFrameFile.readAsBytes();
            }
          } catch (e) {
            debugPrint('读取缩略图失败: $e');
            puzzleThumbnail = _coverFrames[0] ?? _photoThumbnails[0];
          }

          // 🔥 保存成功后添加历史记录
          final photoIds = _selectedPhotos.map((p) => p.id).toList();
          final history = PuzzleHistory(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            photoIds: photoIds,
            createdAt: DateTime.now(),
            thumbnail: puzzleThumbnail,
            photoCount: _selectedPhotos.length,
          );
          await ref.read(puzzleHistoryProvider.notifier).addHistory(history);

          // 🔥 跳转到完成页面
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => CompletionScreen(
                thumbnail: puzzleThumbnail,
                photoCount: _selectedPhotos.length,
              ),
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
    const int MAX_WIDTH = 2000;
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

  /// 🔥 按当前布局渲染一帧到文件（接受已解码的图片，避免重复解码）
  Future<void> _renderLayoutFrameFast(List<ui.Image> decodedImages, int outW, int outH, String outputPath) async {
    if (decodedImages.isEmpty || _imageBlocks.isEmpty) return;

    final cw = _canvasConfig.width;
    final ch = _canvasConfig.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..filterQuality = FilterQuality.high;

    // 白色背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    // 按 imageBlocks 的位置绘制每张图（BoxFit.cover 模式）
    for (int i = 0; i < _imageBlocks.length && i < decodedImages.length; i++) {
      final block = _imageBlocks[i];
      final img = decodedImages[i];

      final dx = block.x * outW;
      final dy = block.y * outH;
      final dw = block.width * outW;
      final dh = block.height * outH;
      final dstRect = Rect.fromLTWH(dx, dy, dw, dh);

      canvas.save();
      canvas.clipRect(dstRect);

      // BoxFit.cover
      final imgW = img.width.toDouble();
      final imgH = img.height.toDouble();
      final dstAspect = dw / dh;
      final srcAspect = imgW / imgH;

      double srcX, srcY, srcW, srcH;
      if (srcAspect > dstAspect) {
        srcH = imgH;
        srcW = imgH * dstAspect;
        srcX = (imgW - srcW) / 2;
        srcY = 0;
      } else {
        srcW = imgW;
        srcH = imgW / dstAspect;
        srcX = 0;
        srcY = (imgH - srcH) / 2;
      }

      // 应用用户的缩放和偏移
      if (block.scale > 1.0 || block.offsetX != 0 || block.offsetY != 0) {
        final zoomedW = srcW / block.scale;
        final zoomedH = srcH / block.scale;
        final oxRatio = block.offsetX / (cw * block.width);
        final oyRatio = block.offsetY / (ch * block.height);
        final cx = srcX + srcW / 2 - oxRatio * zoomedW;
        final cy = srcY + srcH / 2 - oyRatio * zoomedH;
        srcX = (cx - zoomedW / 2).clamp(0, imgW - zoomedW);
        srcY = (cy - zoomedH / 2).clamp(0, imgH - zoomedH);
        srcW = zoomedW;
        srcH = zoomedH;
      }

      canvas.drawImageRect(img, Rect.fromLTWH(srcX, srcY, srcW, srcH), dstRect, paint);
      canvas.restore();
    }

    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(outW, outH);
    final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    await File(outputPath).writeAsBytes(byteData!.buffer.asUint8List());
    finalImage.dispose();
  }

  /// 解码 Uint8List → ui.Image
  Future<ui.Image> _decodeImage(Uint8List data) async {
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    return frame.image;
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
      
      if (_isPlayingLivePuzzle && _animation != null && frames != null && frames.isNotEmpty) {
        // 🔥 播放模式：根据该 Live Photo 的时长决定是否定格
        final progress = _animation!.value.clamp(0.0, 1.0);
        final currentTimeMs = progress * _maxDurationMs;
        final videoDurationMs = _videoDurations[i] ?? 2000;
        
        if (currentTimeMs >= videoDurationMs) {
          // 🔥 当前时间已超过该视频时长，定格到封面
          final coverFrameData = _coverFrames[i];
          if (coverFrameData != null) {
            // 使用自定义封面
            cellImages[i] = coverFrameData;
          } else {
            // 使用原始封面（缩略图）
            cellImages[i] = _photoThumbnails[i];
          }
        } else {
          // 🔥 还在播放时间内，正常播放
          final videoProgress = (currentTimeMs / videoDurationMs).clamp(0.0, 1.0);
          final frameIndex = (videoProgress * (frames.length - 1)).round().clamp(0, frames.length - 1);
          cellImages[i] = frames[frameIndex];
        }
      } else {
        // 🔥 静态显示模式：优先显示自定义封面
        if (_coverFrames[i] != null) {
          cellImages[i] = _coverFrames[i];
        } else {
          cellImages[i] = _photoThumbnails[i];
        }
      }
    }
    
    return cellImages;
  }

  // 🔥 构建新画布（自由交互）
  Widget _buildNewCanvas() {
    if (_selectedPhotos.isEmpty) {
      return const Center(
        child: Text('请选择照片'),
      );
    }

    // 如果还没有应用布局，显示提示
    if (_imageBlocks.isEmpty) {
      return const Center(
        child: Text(
          '请从下方选择画布比例和布局',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    // 使用新的数据驱动画布
    return DataDrivenCanvas(
      canvasConfig: _canvasConfig,
      imageBlocks: _imageBlocks,
      selectedBlockId: _selectedBlockId,
      onBlockTap: (blockId) {
        if (_isPlayingLivePuzzle) return;
        final blockIndex = _imageBlocks.indexWhere((b) => b.id == blockId);

        // 如果点击了已选中的同一张，不做处理
        if (blockIndex == _selectedCellIndex && _selectedBlockId == blockId) return;

        // 先恢复上一张的帧编辑（如果有）
        _revertFrameEdit();

        // 保存当前图片数据，用于取消时恢复
        if (blockIndex >= 0 && blockIndex < _imageBlocks.length) {
          _preEditImageData[blockIndex] = _imageBlocks[blockIndex].imageData;
        }

        setState(() {
          _selectedBlockId = blockId;
          _editorState = EditorState.single;
          if (blockIndex >= 0) {
            _selectedCellIndex = blockIndex;
            _initVideoPlayer(blockIndex);
          }
        });
      },
      onBlockChanged: (blockId, updatedBlock) {
        setState(() {
          final index = _imageBlocks.indexWhere((b) => b.id == blockId);
          if (index >= 0) {
            _imageBlocks[index] = updatedBlock;
          }
        });
      },
      onBlockSwap: (sourceId, targetId) {
        // 位置互换：两个图片块交换 x/y/width/height/layoutBlockId
        final srcIdx = _imageBlocks.indexWhere((b) => b.id == sourceId);
        final tgtIdx = _imageBlocks.indexWhere((b) => b.id == targetId);
        if (srcIdx < 0 || tgtIdx < 0 || srcIdx == tgtIdx) return;

        setState(() {
          final src = _imageBlocks[srcIdx];
          final tgt = _imageBlocks[tgtIdx];

          // 互换位置属性，重置内部偏移
          _imageBlocks[srcIdx] = src.copyWith(
            x: tgt.x, y: tgt.y,
            width: tgt.width, height: tgt.height,
            layoutBlockId: tgt.layoutBlockId,
            offsetX: 0, offsetY: 0,
          );
          _imageBlocks[tgtIdx] = tgt.copyWith(
            x: src.x, y: src.y,
            width: src.width, height: src.height,
            layoutBlockId: src.layoutBlockId,
            offsetX: 0, offsetY: 0,
          );
        });
      },
      onBlocksResized: (updatedBlocks) {
        setState(() {
          _imageBlocks = updatedBlocks;
        });
      },
      onCanvasTap: () {
        if (!_isPlayingLivePuzzle) {
          _handleCanvasTap();
        }
      },
    );
  }

  // 🔥 构建旧画布（列表布局）
  Widget _buildOldCanvas() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_isPlayingLivePuzzle) {
          _handleCanvasTap(); // 使用新的状态切换逻辑
        }
      },
      child: InteractiveViewer(
        minScale: 0.01,
        maxScale: 10.0,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        constrained: false,
        child: Builder(
          builder: (context) {
            if (_isPlayingLivePuzzle && _animation != null) {
              return AnimatedBuilder(
                animation: _animation!,
                builder: (context, child) {
                  return PuzzleGridWidget(
                    selectedCellIndex: _selectedCellIndex,
                    cellImages: _getCellImages(),
                    photoCount: _selectedPhotos.length,
                    onCellTap: (index) async {},
                    onBackgroundTap: () {},
                    onReorder: null,
                  );
                },
              );
            } else {
              return PuzzleGridWidget(
                selectedCellIndex: _selectedCellIndex,
                cellImages: _getCellImages(),
                photoCount: _selectedPhotos.length,
                onCellTap: (index) async {
                  if (_isPlayingLivePuzzle) return;
                  _handleImageTap(index); // 使用新的状态切换逻辑
                },
                onBackgroundTap: () {
                  if (!_isPlayingLivePuzzle) {
                    _handleCanvasTap(); // 使用新的状态切换逻辑
                  }
                },
                onReorder: (fromIndex, toIndex) {
                  if (!_isPlayingLivePuzzle) {
                    _reorderImages(fromIndex, toIndex);
                  }
                },
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 判断是否有可用的帧选择器
    final hasVideoReady = _selectedCellIndex >= 0 &&
        _selectedCellIndex < _selectedPhotos.length &&
        !_isPlayingLivePuzzle &&
        _videoControllers[_selectedCellIndex] != null &&
        _videoControllers[_selectedCellIndex]!.value.isInitialized;

    return WillPopScope(
      onWillPop: () async {
        // 🔥 返回时清空所有选中状态
        ref.read(selectedAllPhotoIdsProvider.notifier).clear();
        ref.read(selectedLivePhotoIdsProvider.notifier).clear();
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF0F5),
        body: Stack(
        children: [
          // ━━━ 主布局 ━━━
          Column(
            children: [
              // 头部
              EditorHeaderWidget(
                onBack: () {
                  // 🔥 返回时清空所有选中状态
                  ref.read(selectedAllPhotoIdsProvider.notifier).clear();
                  ref.read(selectedLivePhotoIdsProvider.notifier).clear();
                  Navigator.pop(context);
                },
                onDone: _savePuzzleToGallery,
                onPlayLive: _selectedPhotos.isNotEmpty ? _playLivePuzzle : null,
                isPlayingLive: _isPlayingLivePuzzle,
              ),

              // 拼图预览画布
              Expanded(
                child: Container(
                  color: const Color(0xFFF5F5F5),
                  child: _useNewCanvas ? _buildNewCanvas() : _buildOldCanvas(),
                ),
              ),

              // 工具栏/布局面板（帧选择器弹出时隐藏）
              if (!_isPlayingLivePuzzle && !hasVideoReady)
                _editorState == EditorState.global
                    ? SizedBox(
                        height: 280,
                        child: LayoutSelectionPanel(
                          photoCount: _selectedPhotos.length,
                          selectedLayoutId: _currentLayout?.id,
                          selectedRatio: _canvasConfig.ratio,
                          onLayoutSelected: (canvas, template) {
                            _applyLayout(canvas, template);
                          },
                        ),
                      )
                    : DynamicToolbar(
                        editorState: _editorState,
                        selectedGlobalTool: _selectedGlobalTool,
                        selectedSingleTool: _selectedSingleTool,
                        onGlobalToolTap: _handleGlobalTool,
                        onSingleToolTap: _handleSingleTool,
                      ),
            ],
          ),

          // ━━━ 帧选择器（底部弹出面板）━━━
          if (hasVideoReady)
            DraggableScrollableSheet(
              key: ValueKey('frame_$_selectedCellIndex'),
              initialChildSize: 0.22,
              minChildSize: 0.14,
              maxChildSize: 0.30,
              snap: true,
              snapSizes: const [0.22],
              builder: (context, scrollController) {
                return VideoFrameSelectorWidget(
                  videoController: _videoControllers[_selectedCellIndex]!,
                  isCover: _coverFrames[_selectedCellIndex] != null,
                  scrollController: scrollController,
                  onFrameTimeChanged: (timeMs) {
                    // 节流提取帧并实时更新画布
                    _throttledExtractFrame(_selectedCellIndex, timeMs);
                  },
                  onConfirm: () => _handleSetCover(_selectedCellIndex),
                  onCancel: () {
                    // 取消：恢复原图并取消选中
                    _revertFrameEdit();
                    setState(() {
                      _selectedCellIndex = -1;
                      _selectedBlockId = null;
                      _editorState = EditorState.global;
                    });
                  },
                );
              },
            ),
        ],
      ),
    ),
    ); // WillPopScope
  }

  /// 设置封面帧（确定时调用）
  Future<void> _handleSetCover(int cellIndex) async {
    _frameExtractTimer?.cancel();
    final frameData = await _captureVideoFrame(cellIndex);

    if (frameData != null) {
      final controller = _videoControllers[cellIndex]!;
      final timeMs = controller.value.position.inMilliseconds;

      setState(() {
        _coverFrames[cellIndex] = frameData;
        _coverFrameTime[cellIndex] = timeMs;
        _currentDisplayImages[cellIndex] = frameData;
        // 更新画布图片为确认的封面帧
        if (cellIndex < _imageBlocks.length) {
          _imageBlocks[cellIndex] = _imageBlocks[cellIndex].copyWith(
            imageData: frameData,
          );
        }
      });

      // 确认后清除预编辑数据（这样取消选中不会恢复）
      _preEditImageData.remove(cellIndex);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已设置为封面 (${(timeMs / 1000).toStringAsFixed(2)}s)',
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
  }
}
