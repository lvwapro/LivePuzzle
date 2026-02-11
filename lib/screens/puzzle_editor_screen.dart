import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_puzzle/providers/photo_provider.dart';
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
import 'puzzle_editor/feature_buttons_widget.dart';
import 'puzzle_editor/interactive_canvas_widget.dart';
import 'puzzle_editor/image_action_menu.dart';
import 'puzzle_editor/dynamic_toolbar.dart';
import 'puzzle_editor/layout_selection_panel.dart';
import 'puzzle_editor/data_driven_canvas.dart';

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
  
  // 🔥 布局管理（旧系统，逐步废弃）
  final Map<int, ImageTransform> _imageTransforms = {};
  bool _useNewCanvas = false; // 切换开关，true 使用新画布，false 使用旧布局
  
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
  final Map<int, int?> _coverFrameTime = {}; // 存储封面帧的时间点（毫秒）
  
  // 🔥 Live 拼图播放
  AnimationController? _animationController;
  Animation<double>? _animation;
  bool _isPlayingLivePuzzle = false;
  
  // 🔥 当前显示的图片（用于网格显示）
  final Map<int, Uint8List?> _currentDisplayImages = {};

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
          // 🔥 初始化状态
          for (int i = 0; i < selectedAssets.length; i++) {
            if (!_selectedFrames.containsKey(i)) {
              _selectedFrames[i] = 0; // 初始显示第一帧
            }
            if (!_coverFrames.containsKey(i)) {
              _coverFrames[i] = null; // null表示使用原始封面
            }
            // 🔥 初始化图片变换状态 - 自动垂直排列
            if (!_imageTransforms.containsKey(i)) {
              _imageTransforms[i] = ImageTransform(
                position: Offset(100, 100.0 + i * 320.0), // 垂直排列，间距320
                scale: 1.0,
                rotation: 0.0,
                zIndex: i,
              );
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
                  // 🔥 恢复到各自的封面
                  for (int i = 0; i < _selectedPhotos.length; i++) {
                    final coverFrameData = _coverFrames[i];
                    if (coverFrameData != null) {
                      _currentDisplayImages[i] = coverFrameData;
                    } else {
                      _currentDisplayImages[i] = _photoThumbnails[i];
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
        
        // 🔥 自动应用长图纵向拼接布局
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (mounted && _selectedPhotos.isNotEmpty) {
            final template = LayoutTemplate.getLongImageLayouts(_selectedPhotos.length)
                .firstWhere((t) => t.id == 'long_vertical');
            
            // 等待缩略图加载完成
            await Future.delayed(const Duration(milliseconds: 800));
            
            if (mounted) {
              final dummyCanvas = CanvasConfig.fromRatio('1:1'); // 占位，会被重新计算
              _applyLayout(dummyCanvas, template);
            }
          }
        });
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
    setState(() {
      _selectedCellIndex = -1;
      _editorState = EditorState.global; // 切换回全局编辑状态
      _selectedGlobalTool = null; // 清空工具选择
    });
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

  // 🔥 应用布局
  // 🔥 应用布局（使用新的数据驱动系统）
  void _applyLayout(CanvasConfig canvas, LayoutTemplate template) async {
    if (_selectedPhotos.isEmpty) return;
    
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
    
    setState(() {
      _useNewCanvas = true; // 使用新画布
      _canvasConfig = finalCanvas; // 保存画布配置
      _currentLayout = template; // 保存当前布局
      
      // 使用布局引擎计算图片块位置（相对坐标 0-1）
      _imageBlocks = LayoutEngine.calculateLayout(
        canvas: finalCanvas,
        template: template,
        images: images,
        spacing: 0.0, // 🔥 无间距
      );
      
      // 重置选中状态
      _selectedBlockId = null;
      _editorState = EditorState.global;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已应用 ${template.name} 布局 (${images.length}张)'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFFFF85A2),
      ),
    );
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

  Future<void> _playLivePuzzle() async {
    if (_animationController == null || _animation == null) return;
    
    if (_isPlayingLivePuzzle) {
      // 🔥 停止播放，恢复到各自的封面帧
      debugPrint('⏸️ 停止播放 Live Puzzle');
      setState(() {
        _isPlayingLivePuzzle = false;
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
        final coverFrameData = _coverFrames[i];
        if (coverFrameData != null) {
          // 设置了自定义封面，使用截取的图片
          coverCellFrames.add(coverFrameData);
        } else if (_photoThumbnails[i] != null) {
          // 没设置封面，使用缩略图（已经是1200x1200高质量）
          coverCellFrames.add(_photoThumbnails[i]!);
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
              final coverFrameData = _coverFrames[i];
              if (coverFrameData != null) {
                // 使用自定义封面
                cellFrames.add(coverFrameData);
              } else if (_photoThumbnails[i] != null) {
                // 使用缩略图（已经是1200x1200高质量）
                cellFrames.add(_photoThumbnails[i]!);
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
        print('🔍 Block tapped: $blockId');
        final blockIndex = _imageBlocks.indexWhere((b) => b.id == blockId);
        print('🔍 Block index: $blockIndex, _selectedCellIndex before: $_selectedCellIndex');
        
        setState(() {
          _selectedBlockId = blockId;
          _editorState = EditorState.single;
          
          if (blockIndex >= 0) {
            _selectedCellIndex = blockIndex;
            print('🔍 Set _selectedCellIndex to: $blockIndex');
            // 🔥 自动初始化视频播放器，用于帧选择
            _initVideoPlayer(blockIndex);
          }
        });
        
        print('🔍 _selectedCellIndex after setState: $_selectedCellIndex');
        print('🔍 _useNewCanvas: $_useNewCanvas');
        print('🔍 Video controller exists: ${_videoControllers[blockIndex] != null}');
      },
      onBlockChanged: (blockId, updatedBlock) {
        setState(() {
          final index = _imageBlocks.indexWhere((b) => b.id == blockId);
          if (index >= 0) {
            _imageBlocks[index] = updatedBlock;
          }
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
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: Column(
        children: [
          // 头部
          EditorHeaderWidget(
            onBack: () => Navigator.pop(context),
            onDone: _savePuzzleToGallery,
          onPlayLive: _selectedPhotos.isNotEmpty ? _playLivePuzzle : null,
          isPlayingLive: _isPlayingLivePuzzle,
        ),

        // 🔥 拼图预览画布
        Expanded(
            child: Container(
              color: const Color(0xFFF5F5F5),
              child: _useNewCanvas ? _buildNewCanvas() : _buildOldCanvas(),
            ),
          ),

          // 底部控制区域 - 帧选择器（保留定格帧选择功能）
          if (_selectedCellIndex >= 0 && _selectedCellIndex < _selectedPhotos.length && !_isPlayingLivePuzzle)
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _videoControllers[_selectedCellIndex] != null &&
                            _videoControllers[_selectedCellIndex]!.value.isInitialized
                          ? VideoFrameSelectorWidget(
                              videoController: _videoControllers[_selectedCellIndex]!,
                              isCover: _coverFrames[_selectedCellIndex] != null,
                              onSetCover: () async {
                                final frameData = await _captureVideoFrame(_selectedCellIndex);
                                
                                if (frameData != null) {
                                  final controller = _videoControllers[_selectedCellIndex]!;
                                  final timeMs = controller.value.position.inMilliseconds;
                                  
                                  setState(() {
                                    _coverFrames[_selectedCellIndex] = frameData;
                                    _coverFrameTime[_selectedCellIndex] = timeMs;
                                    _currentDisplayImages[_selectedCellIndex] = frameData;
                                  });
                                  
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
                  ],
                ),
              ),
            ),

          // 🔥 动态工具栏/布局面板
          if (!_isPlayingLivePuzzle)
            _editorState == EditorState.global
                ? SizedBox(
                    height: 280, // 🔥 从400降到280
                    child: LayoutSelectionPanel(
                      photoCount: _selectedPhotos.length, // 🔥 传入图片数量
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
    );
  }
}
