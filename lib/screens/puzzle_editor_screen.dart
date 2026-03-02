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
import 'package:flutter/foundation.dart';
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
import 'package:live_puzzle/l10n/app_localizations.dart';

/// 拼图编辑器页面 - Seamless Puzzle风格
class PuzzleEditorScreen extends ConsumerStatefulWidget {
  const PuzzleEditorScreen({super.key});

  @override
  ConsumerState<PuzzleEditorScreen> createState() => _PuzzleEditorScreenState();
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
  final Map<int, int?> _coverFrameTime = {}; // 存储封面帧的时间点（毫秒）
  final Map<int, int> _currentSliderTimeMs = {}; // 滑块当前选中时间（不依赖 seekTo 异步结果）

  // 🔥 Live 拼图播放
  AnimationController? _animationController;
  Animation<double>? _animation;
  bool _isPlayingLivePuzzle = false;

  // 🔥 当前显示的图片（用于网格显示）
  final Map<int, Uint8List?> _currentDisplayImages = {};

  // 🔥 帧编辑：进入帧选择时保存原始图片，取消时恢复
  final Map<int, Uint8List?> _preEditImageData = {};
  Timer? _frameExtractTimer;

  /// 从首页历史进入时传入，用于恢复上次布局与封面帧（用后即清）
  PuzzleHistory? _restoreHistory;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 在 didChangeDependencies 中读取 route arguments，避免在 initState 中调用 ModalRoute.of(context)
    if (_restoreHistory == null) {
      _restoreHistory =
          ModalRoute.of(context)?.settings.arguments as PuzzleHistory?;
    }
  }

  @override
  void dispose() {
    _frameExtractTimer?.cancel();
    _animationController?.dispose();
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
        LayoutTemplate.presetLayouts
            .firstWhere((t) => t.id == 'grid_2x1') // 上下平分
      );
    } else if (photoCount == 3) {
      return (
        CanvasConfig.fromRatio('9:16'),
        LayoutTemplate.presetLayouts
            .firstWhere((t) => t.id == 'grid_3x1') // 三行一列
      );
    } else {
      // 4-9张：长图纵向拼接
      return (
        CanvasConfig.fromRatio('1:1'), // 占位，会被重新计算
        LayoutTemplate.getLongImageLayouts(photoCount)
            .firstWhere((t) => t.id == 'long_vertical')
      );
    }
  }

  /// 根据 id 和图片数量查找布局模板（预设或长图）
  LayoutTemplate? _findTemplateById(String id, int photoCount) {
    try {
      return LayoutTemplate.presetLayouts
          .where((t) => t.imageCount == photoCount)
          .firstWhere((t) => t.id == id);
    } catch (_) {
      try {
        return LayoutTemplate.getLongImageLayouts(photoCount)
            .firstWhere((t) => t.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _loadSelectedPhotos() async {
    // 若尚未从 didChangeDependencies 取得，在此处再取一次（确保 route 已挂载）
    if (_restoreHistory == null && mounted) {
      _restoreHistory =
          ModalRoute.of(context)?.settings.arguments as PuzzleHistory?;
    }

    final selectedAllIds = ref.read(selectedAllPhotoIdsProvider);
    final selectedLiveIds = ref.read(selectedLivePhotoIdsProvider);

    final selectedIds =
        selectedLiveIds.isNotEmpty ? selectedLiveIds : selectedAllIds;

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
        final restore = _restoreHistory;
        _restoreHistory = null;

        // 用实际加载的 asset id 列表与历史一致则恢复（顺序一致）
        final loadedIds = selectedAssets.map((a) => a.id).toList();
        CanvasConfig canvas;
        LayoutTemplate template;
        final useRestore = restore != null &&
            listEquals(restore.photoIds, loadedIds) &&
            restore.lastLayoutId != null &&
            restore.lastRatio != null;
        if (useRestore) {
          final t =
              _findTemplateById(restore.lastLayoutId!, selectedAssets.length);
          if (t != null) {
            template = t;
            canvas = CanvasConfig.fromRatio(restore.lastRatio!);
          } else {
            final initial = _getInitialLayout(selectedAssets.length);
            canvas = initial.$1;
            template = initial.$2;
          }
        } else {
          final initial = _getInitialLayout(selectedAssets.length);
          canvas = initial.$1;
          template = initial.$2;
        }

        setState(() {
          _selectedPhotos = selectedAssets;
          _canvasConfig = canvas;
          _currentLayout = template;

          for (int i = 0; i < selectedAssets.length; i++) {
            if (!_selectedFrames.containsKey(i)) {
              _selectedFrames[i] = 0;
            }
            if (!_coverFrames.containsKey(i)) {
              _coverFrames[i] = null;
            }
            if (useRestore &&
                restore.lastCoverFrameTimeMs != null &&
                i < restore.lastCoverFrameTimeMs!.length &&
                restore.lastCoverFrameTimeMs![i] >= 0) {
              _coverFrameTime[i] = restore.lastCoverFrameTimeMs![i];
            } else {
              _coverFrameTime[i] = null;
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
          // 若恢复了封面帧时间，异步拉取对应帧并设为封面
          final hasCoverTimes = List.generate(_selectedPhotos.length, (i) => i)
              .any((i) =>
                  _coverFrameTime[i] != null && _coverFrameTime[i]! >= 0);
          if (mounted && hasCoverTimes) {
            _restoreCoverFramesFromSavedTimes();
          }

          // 后台预提取所有视频帧（不阻塞UI）
          _preExtractAllVideoFrames();
        }
      }
    });
  }

  /// 根据已保存的 _coverFrameTime 拉取视频帧并设为封面（从历史恢复时调用）
  Future<void> _restoreCoverFramesFromSavedTimes() async {
    for (int i = 0; i < _selectedPhotos.length; i++) {
      final timeMs = _coverFrameTime[i];
      if (timeMs == null || timeMs < 0) continue;
      await _extractVideoFrames(i);
      if (!mounted) return;
      final frames = _videoFrames[i];
      if (frames == null || frames.isEmpty) continue;
      final durationMs = _videoDurations[i] ?? 2000;
      final progress = (timeMs / durationMs).clamp(0.0, 1.0);
      final frameIndex =
          (progress * (frames.length - 1)).round().clamp(0, frames.length - 1);
      final frameData = frames[frameIndex];
      if (mounted && frameData != null && i < _imageBlocks.length) {
        setState(() {
          _coverFrames[i] = frameData;
          _currentDisplayImages[i] = frameData;
          _imageBlocks[i] = _imageBlocks[i].copyWith(imageData: frameData);
        });
      }
    }
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
      // 优先用滑块记录的时间，避免 seekTo 异步未完成导致读到错误位置
      final timeMs = _currentSliderTimeMs[cellIndex] ??
          controller.value.position.inMilliseconds;
      debugPrint('🎞️ 截帧: cell=$cellIndex, time=${timeMs}ms');
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
    if (fromIndex >= _selectedPhotos.length ||
        toIndex >= _selectedPhotos.length) return;

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
    if (_selectedCellIndex >= 0 &&
        _preEditImageData.containsKey(_selectedCellIndex)) {
      final originalData = _preEditImageData[_selectedCellIndex];
      if (originalData != null && _selectedCellIndex < _imageBlocks.length) {
        setState(() {
          _imageBlocks[_selectedCellIndex] =
              _imageBlocks[_selectedCellIndex].copyWith(
            imageData: originalData,
          );
        });
      }
      _preEditImageData.remove(_selectedCellIndex);
    }
  }

  /// 拖动 Slider 时使用已提取的帧做即时预览（零延迟），避免原生 extractFrame 的磁盘 I/O 卡顿
  void _throttledExtractFrame(int cellIndex, int timeMs) {
    if (!mounted || cellIndex < 0 || cellIndex >= _imageBlocks.length) return;

    // 记录滑块选中时间，供 _handleSetCover 使用（不依赖 seekTo 异步结果）
    _currentSliderTimeMs[cellIndex] = timeMs;

    final frames = _videoFrames[cellIndex];
    if (frames != null && frames.isNotEmpty) {
      // 用预提取帧做即时预览
      final durationMs = _videoDurations[cellIndex] ?? 2000;
      final progress = (timeMs / durationMs).clamp(0.0, 1.0);
      final frameIndex =
          (progress * (frames.length - 1)).round().clamp(0, frames.length - 1);
      setState(() {
        _imageBlocks[cellIndex] = _imageBlocks[cellIndex].copyWith(
          imageData: frames[frameIndex],
        );
      });
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
    final isLongImage =
        template.id == 'long_horizontal' || template.id == 'long_vertical';

    if (isLongImage) {
      // 🔥 长图：按每张图片的真实比例计算画布和分块，一次性 setState
      final (longCanvas, longBlocks) =
          await _calculateLongImageCanvasAndBlocks(template, images);
      if (!mounted) return;
      setState(() {
        _useNewCanvas = true;
        _canvasConfig = longCanvas;
        _currentLayout = template;
        _imageBlocks = longBlocks;
        _selectedBlockId = null;
        _editorState = EditorState.global;
      });
      return;
    }

    // 非长图：先更新画布与模板，避免布局面板与画布不同步
    setState(() {
      _canvasConfig = canvas;
      _currentLayout = template;
    });

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
      _canvasConfig = canvas;
      _currentLayout = template;

      _imageBlocks = LayoutEngine.calculateLayout(
        canvas: canvas,
        template: template,
        images: images,
        spacing: 0.0,
      );

      // 🔥 为每个 block 设置图片宽高比
      for (int i = 0; i < _imageBlocks.length && i < aspectRatios.length; i++) {
        _imageBlocks[i] =
            _imageBlocks[i].copyWith(imageAspectRatio: aspectRatios[i]);
      }

      _selectedBlockId = null;
      _editorState = EditorState.global;
    });
  }

  /// 🔥 计算长图拼接的画布尺寸和比例分块（基于每张图片的真实尺寸）
  ///
  /// 纵向：统一宽度，每块高度 = (图片高/图片宽) × 统一宽度
  /// 横向：统一高度，每块宽度 = (图片宽/图片高) × 统一高度
  /// 这样每个 block 的宽高比与原图完全一致，不会裁剪任何内容。
  Future<(CanvasConfig, List<ImageBlock>)> _calculateLongImageCanvasAndBlocks(
    LayoutTemplate template,
    List<Uint8List> images,
  ) async {
    if (images.isEmpty) {
      return (CanvasConfig.fromRatio('1:1'), <ImageBlock>[]);
    }

    final isHorizontal = template.id == 'long_horizontal';

    // 一次解码获取实际尺寸
    final imageSizes = <Size>[];
    for (final imageData in images) {
      try {
        final codec = await ui.instantiateImageCodec(imageData);
        final frame = await codec.getNextFrame();
        imageSizes.add(Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        ));
        frame.image.dispose();
        codec.dispose();
      } catch (_) {
        imageSizes.add(const Size(1080, 1920));
      }
    }

    final blocks = <ImageBlock>[];
    late CanvasConfig canvas;

    if (isHorizontal) {
      // 横向：统一高度 = 所有图片中最大高度，各图按比例调整宽度
      final unifiedH = imageSizes.map((s) => s.height).reduce(math.max);
      final scaledWidths = imageSizes
          .map((s) => (s.width / s.height) * unifiedH)
          .toList();
      final totalWidth = scaledWidths.fold(0.0, (a, b) => a + b);

      canvas = CanvasConfig(
        width: totalWidth,
        height: unifiedH,
        ratio: '${totalWidth.toInt()}:${unifiedH.toInt()}',
        type: CanvasRatioType.custom,
      );

      double cumX = 0;
      for (int i = 0; i < imageSizes.length; i++) {
        final blockW = scaledWidths[i] / totalWidth;
        blocks.add(ImageBlock(
          id: 'block_$i',
          layoutBlockId: '${template.id}_$i',
          x: cumX / totalWidth,
          y: 0,
          width: blockW,
          height: 1.0,
          imageData: images[i],
          imageAspectRatio: imageSizes[i].width / imageSizes[i].height,
          zIndex: i,
        ));
        cumX += scaledWidths[i];
      }

      debugPrint('📐 横向长图: ${totalWidth.toInt()}×${unifiedH.toInt()}, ${blocks.length} 块');
    } else {
      // 纵向：统一宽度 = 所有图片中最大宽度，各图按比例调整高度
      final unifiedW = imageSizes.map((s) => s.width).reduce(math.max);
      final scaledHeights = imageSizes
          .map((s) => (s.height / s.width) * unifiedW)
          .toList();
      final totalHeight = scaledHeights.fold(0.0, (a, b) => a + b);

      canvas = CanvasConfig(
        width: unifiedW,
        height: totalHeight,
        ratio: '${unifiedW.toInt()}:${totalHeight.toInt()}',
        type: CanvasRatioType.custom,
      );

      double cumY = 0;
      for (int i = 0; i < imageSizes.length; i++) {
        final blockH = scaledHeights[i] / totalHeight;
        blocks.add(ImageBlock(
          id: 'block_$i',
          layoutBlockId: '${template.id}_$i',
          x: 0,
          y: cumY / totalHeight,
          width: 1.0,
          height: blockH,
          imageData: images[i],
          imageAspectRatio: imageSizes[i].width / imageSizes[i].height,
          zIndex: i,
        ));
        cumY += scaledHeights[i];
      }

      debugPrint('📐 纵向长图: ${unifiedW.toInt()}×${totalHeight.toInt()}, ${blocks.length} 块');
    }

    return (canvas, blocks);
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
      final transform =
          _imageTransforms[_selectedCellIndex] ?? ImageTransform();
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
      final maxZ = _imageTransforms.values
          .map((t) => t.zIndex)
          .fold(0, (a, b) => a > b ? a : b);
      _imageTransforms[index] =
          _imageTransforms[index]!.copyWith(zIndex: maxZ + 1);
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
      final minZ = _imageTransforms.values
          .map((t) => t.zIndex)
          .fold(0, (a, b) => a < b ? a : b);
      _imageTransforms[index] =
          _imageTransforms[index]!.copyWith(zIndex: minZ - 1);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已置于底层'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// 页面加载后在后台逐个预提取所有视频帧，避免点击 Live/帧选择时等待
  Future<void> _preExtractAllVideoFrames() async {
    for (int i = 0; i < _selectedPhotos.length; i++) {
      if (!mounted) return;
      if (_videoFrames.containsKey(i)) continue;
      await _extractVideoFrames(i);
    }
    if (mounted) {
      debugPrint('✅ 所有视频帧预提取完成 (${_videoFrames.length}/${_selectedPhotos.length})');
    }
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
          final framePath =
              await LivePhotoBridge.extractFrame(videoPath, timeMs);
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
    for (int i = 0;
        i < _imageBlocks.length && i < _selectedPhotos.length;
        i++) {
      final frames = _videoFrames[i];
      Uint8List? newData;

      if (frames != null && frames.isNotEmpty) {
        final videoDurationMs = _videoDurations[i] ?? 2000;
        if (currentTimeMs >= videoDurationMs) {
          // 超过该视频时长 → 定格到封面
          newData = _coverFrames[i] ?? _photoThumbnails[i];
        } else {
          // 正常播放
          final videoProgress =
              (currentTimeMs / videoDurationMs).clamp(0.0, 1.0);
          final frameIndex = (videoProgress * (frames.length - 1))
              .round()
              .clamp(0, frames.length - 1);
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
    for (int i = 0;
        i < _imageBlocks.length && i < _selectedPhotos.length;
        i++) {
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

  // 🔥 保存拼图到图库（Live Photo 格式）- 🚀 硬件加速版本
  Future<void> _savePuzzleToGallery() async {
    if (_selectedPhotos.isEmpty) return;

    // 创建进度通知器
    final progressNotifier = ValueNotifier<double>(0.0);
    final messageNotifier = ValueNotifier<String>('准备中...');

    try {
      // 显示进度对话框
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 进度条
                  ValueListenableBuilder<double>(
                    valueListenable: progressNotifier,
                    builder: (context, progress, child) {
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: const Color(0xFFFFE0E8),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFFF4D80),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF4D80),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // 状态文本
                  ValueListenableBuilder<String>(
                    valueListenable: messageNotifier,
                    builder: (context, message, child) {
                      return Text(
                        message,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final sw = Stopwatch()..start();

      // 🚀 使用硬件加速合成（无需提取和渲染所有帧）
      if (_useNewCanvas && _imageBlocks.isNotEmpty) {
        debugPrint('🚀 使用硬件加速模式导出...');
        
        messageNotifier.value = '正在准备布局配置...';
        progressNotifier.value = 0.1;

        // 准备布局配置
        final isLongImageLayout = _currentLayout?.id == 'long_horizontal' ||
            _currentLayout?.id == 'long_vertical';
        final layoutConfig = {
          'canvasWidth': _canvasConfig.width,
          'canvasHeight': _canvasConfig.height,
          'isLongImage': isLongImageLayout,
          'blocks': _imageBlocks.map((block) => {
            'x': block.x,
            'y': block.y,
            'width': block.width,
            'height': block.height,
            'scale': block.scale,
            'offsetX': block.offsetX,
            'offsetY': block.offsetY,
          }).toList(),
        };

        // 诊断日志
        debugPrint('🔍 画布: ${_canvasConfig.width}×${_canvasConfig.height} ratio=${_canvasConfig.ratio}');
        for (int i = 0; i < _imageBlocks.length; i++) {
          final b = _imageBlocks[i];
          debugPrint('🔍 Block[$i]: x=${b.x.toStringAsFixed(3)} y=${b.y.toStringAsFixed(3)} w=${b.width.toStringAsFixed(3)} h=${b.height.toStringAsFixed(3)} scale=${b.scale} offsetX=${b.offsetX} offsetY=${b.offsetY}');
        }

        // 准备封面时间
        final coverTimes = List<int>.generate(
          _selectedPhotos.length,
          (i) => _coverFrameTime[i] ?? 0,
        );

        // 准备 asset IDs
        final assetIds = _selectedPhotos.map((p) => p.id).toList();

        messageNotifier.value = '正在硬件编码合成...';
        progressNotifier.value = 0.2;

        // 调用硬件加速方法
        final success = await LivePhotoBridge.createLivePhotoHardware(
          assetIds: assetIds,
          layoutConfig: layoutConfig,
          coverTimes: coverTimes,
        );

        progressNotifier.value = 1.0;
        messageNotifier.value = '完成！';

        debugPrint('⏱️ 硬件加速导出完成，总耗时 ${sw.elapsedMilliseconds}ms');

        if (mounted) {
          // 关闭加载对话框
          Navigator.of(context, rootNavigator: true).pop();

          if (success) {
            // 准备缩略图（合成画布全图）
            final puzzleThumbnail =
                await _buildCompositeThumbnail() ?? _photoThumbnails[0];

            // 保存历史记录
            final photoIds = _selectedPhotos.map((p) => p.id).toList();
            final coverMs = List<int>.generate(
              _selectedPhotos.length,
              (i) => _coverFrameTime[i] ?? -1,
            );
            final history = PuzzleHistory(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              photoIds: photoIds,
              createdAt: DateTime.now(),
              thumbnail: puzzleThumbnail,
              photoCount: _selectedPhotos.length,
              lastLayoutId: _currentLayout?.id,
              lastRatio: _canvasConfig.ratio,
              lastCoverFrameTimeMs: coverMs,
            );
            await ref.read(puzzleHistoryProvider.notifier).addHistory(history);

            // 跳转到完成页面
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => CompletionScreen(
                  thumbnail: puzzleThumbnail,
                  photoCount: _selectedPhotos.length,
                  imageAspectRatio: _canvasConfig.width / _canvasConfig.height,
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
        return;
      }

      // 旧版软编码逻辑（作为备用，仅在未使用新画布时）
      debugPrint('⚠️ 使用旧版软编码模式（较慢）');
      messageNotifier.value = '正在加载视频帧...';
      
      // [保留原有的软编码逻辑作为备用...]
      for (int i = 0; i < _selectedPhotos.length; i++) {
        if (!_videoFrames.containsKey(i)) {
          await _extractVideoFrames(i);
        }
        progressNotifier.value = 0.1 * (i + 1) / _selectedPhotos.length;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final frameImagePaths = <String>[];

      // 简化的旧版逻辑（纵向拼接）
      List<Uint8List> getFrameCellData(int frameIdx) {
        final cellFrames = <Uint8List>[];
        for (int i = 0; i < _selectedPhotos.length; i++) {
          if (frameIdx == 0) {
            final coverData = _coverFrames[i] ?? _photoThumbnails[i];
            if (coverData != null) cellFrames.add(coverData);
          } else {
            final frames = _videoFrames[i];
            if (frames != null && frames.isNotEmpty) {
              final progress = frameIdx / (kTotalFrames - 1);
              final currentTimeMs = progress * _maxDurationMs;
              final videoDurationMs = _videoDurations[i] ?? 3000; // Apple标准3秒
              if (currentTimeMs >= videoDurationMs) {
                final coverData = _coverFrames[i] ?? _photoThumbnails[i];
                if (coverData != null) cellFrames.add(coverData);
              } else {
                final videoProgress =
                    (currentTimeMs / videoDurationMs).clamp(0.0, 1.0);
                final fi = (videoProgress * (frames.length - 1))
                    .round()
                    .clamp(0, frames.length - 1);
                cellFrames.add(frames[fi]);
              }
            } else if (_photoThumbnails[i] != null) {
              cellFrames.add(_photoThumbnails[i]!);
            }
          }
        }
        return cellFrames;
      }

      messageNotifier.value = '正在渲染帧...';
      for (int frameIdx = 0; frameIdx < kTotalFrames; frameIdx++) {
        final cellData = getFrameCellData(frameIdx);
        final framePath =
            '${tempDir.path}/puzzle_frame_${timestamp}_$frameIdx.jpg';
        await _stitchImages(cellData, framePath);
        frameImagePaths.add(framePath);
        progressNotifier.value = 0.1 + 0.7 * (frameIdx + 1) / kTotalFrames;
      }

      debugPrint('⏱️ 软编码渲染完成，耗时 ${sw.elapsedMilliseconds}ms');

      messageNotifier.value = '正在保存到相册...';
      progressNotifier.value = 0.85;

      final success =
          await LivePhotoBridge.createLivePhoto(frameImagePaths, 0);

      progressNotifier.value = 1.0;
      messageNotifier.value = '完成！';

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        if (success) {
          // 生成合成缩略图
          final puzzleThumbnail =
              await _buildCompositeThumbnail() ?? _photoThumbnails[0];

          final photoIds = _selectedPhotos.map((p) => p.id).toList();
          final coverMs = List<int>.generate(
            _selectedPhotos.length,
            (i) => _coverFrameTime[i] ?? -1,
          );
          final history = PuzzleHistory(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            photoIds: photoIds,
            createdAt: DateTime.now(),
            thumbnail: puzzleThumbnail,
            photoCount: _selectedPhotos.length,
            lastLayoutId: _currentLayout?.id,
            lastRatio: _canvasConfig.ratio,
            lastCoverFrameTimeMs: coverMs,
          );
          await ref.read(puzzleHistoryProvider.notifier).addHistory(history);

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => CompletionScreen(
                thumbnail: puzzleThumbnail,
                photoCount: _selectedPhotos.length,
                imageAspectRatio: 3 / 4, // 默认比例
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

      // 清理临时文件
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
        Navigator.of(context, rootNavigator: true).pop();
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
    } finally {
      progressNotifier.dispose();
      messageNotifier.dispose();
    }
  }

  // 🔥 拼接多张图片为一张竖向长图（高清版本）
  Future<void> _stitchImages(
      List<Uint8List> imageDataList, String outputPath) async {
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
    final paint = Paint()..filterQuality = FilterQuality.high; // 🔥 使用高质量过滤

    int currentY = 0;

    // 绘制每张图片
    for (final image in images) {
      final aspectRatio = image.height / image.width;
      final scaledHeight = (maxWidth * aspectRatio).round();

      final srcRect =
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      final dstRect = Rect.fromLTWH(
          0, currentY.toDouble(), maxWidth.toDouble(), scaledHeight.toDouble());

      canvas.drawImageRect(image, srcRect, dstRect, paint);
      currentY += scaledHeight;
    }

    // 转换为图片（保持原始分辨率）
    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(maxWidth, totalHeight);
    final byteData =
        await finalImage.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    // 保存到文件
    await File(outputPath).writeAsBytes(pngBytes);

    debugPrint(
        '✅ 拼接完成: ${(pngBytes.length / 1024 / 1024).toStringAsFixed(2)} MB');

    // 清理资源
    for (final image in images) {
      image.dispose();
    }
    finalImage.dispose();
  }

  /// 🔥 按当前布局渲染一帧到文件（接受已解码的图片，避免重复解码）
  Future<void> _renderLayoutFrameFast(List<ui.Image> decodedImages, int outW,
      int outH, String outputPath) async {
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

      canvas.drawImageRect(
          img, Rect.fromLTWH(srcX, srcY, srcW, srcH), dstRect, paint);
      canvas.restore();
    }

    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(outW, outH);
    final byteData =
        await finalImage.toByteData(format: ui.ImageByteFormat.png);
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

      if (_isPlayingLivePuzzle &&
          _animation != null &&
          frames != null &&
          frames.isNotEmpty) {
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
          final videoProgress =
              (currentTimeMs / videoDurationMs).clamp(0.0, 1.0);
          final frameIndex = (videoProgress * (frames.length - 1))
              .round()
              .clamp(0, frames.length - 1);
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
        if (blockIndex == _selectedCellIndex && _selectedBlockId == blockId)
          return;

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
            x: tgt.x,
            y: tgt.y,
            width: tgt.width,
            height: tgt.height,
            layoutBlockId: tgt.layoutBlockId,
            offsetX: 0,
            offsetY: 0,
          );
          _imageBlocks[tgtIdx] = tgt.copyWith(
            x: src.x,
            y: src.y,
            width: src.width,
            height: src.height,
            layoutBlockId: src.layoutBlockId,
            offsetX: 0,
            offsetY: 0,
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
                  onPlayLive:
                      _selectedPhotos.isNotEmpty ? _playLivePuzzle : null,
                  isPlayingLive: _isPlayingLivePuzzle,
                ),

                // 拼图预览画布
                Expanded(
                  child: Container(
                    color: const Color(0xFFF5F5F5),
                    child:
                        _useNewCanvas ? _buildNewCanvas() : _buildOldCanvas(),
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

  /// 生成拼图画布的合成缩略图（用于完成页展示）
  Future<Uint8List?> _buildCompositeThumbnail() async {
    if (_imageBlocks.isEmpty) return null;
    const double maxSide = 800.0;
    final ratio = _canvasConfig.width / _canvasConfig.height;
    final double canvasW = ratio >= 1.0 ? maxSide : maxSide * ratio;
    final double canvasH = ratio >= 1.0 ? maxSide / ratio : maxSide;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasW, canvasH));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasW, canvasH),
      Paint()..color = const Color(0xFF000000),
    );

    for (int i = 0; i < _imageBlocks.length; i++) {
      final block = _imageBlocks[i];
      final imageData = _coverFrames[i] ?? _photoThumbnails[i];
      if (imageData == null) continue;
      try {
        final codec = await ui.instantiateImageCodec(imageData);
        final frame = await codec.getNextFrame();
        final image = frame.image;

        final dstRect = Rect.fromLTWH(
          block.x * canvasW,
          block.y * canvasH,
          block.width * canvasW,
          block.height * canvasH,
        );
        final srcW = image.width.toDouble();
        final srcH = image.height.toDouble();
        final srcAspect = srcW / srcH;
        final dstAspect = dstRect.width / dstRect.height;

        Rect srcRect;
        if (srcAspect > dstAspect) {
          final cropW = srcH * dstAspect;
          final offsetX = (block.offsetX / _canvasConfig.width) * srcW;
          final cropX = ((srcW - cropW) / 2 - offsetX).clamp(0.0, srcW - cropW);
          srcRect = Rect.fromLTWH(cropX, 0, cropW, srcH);
        } else {
          final cropH = srcW / dstAspect;
          final offsetY = (block.offsetY / _canvasConfig.height) * srcH;
          final cropY = ((srcH - cropH) / 2 - offsetY).clamp(0.0, srcH - cropH);
          srcRect = Rect.fromLTWH(0, cropY, srcW, cropH);
        }

        canvas.save();
        canvas.clipRect(dstRect);
        canvas.drawImageRect(
          image,
          srcRect,
          dstRect,
          Paint()..filterQuality = FilterQuality.medium,
        );
        canvas.restore();
        image.dispose();
      } catch (e) {
        debugPrint('⚠️ 合成缩略图 block[$i] 失败: $e');
      }
    }

    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(canvasW.round(), canvasH.round());
    final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    finalImage.dispose();
    return byteData?.buffer.asUint8List();
  }

  /// 设置封面帧（确定时调用）
  Future<void> _handleSetCover(int cellIndex) async {
    _frameExtractTimer?.cancel();
    final frameData = await _captureVideoFrame(cellIndex);

    if (frameData != null) {
      final controller = _videoControllers[cellIndex];
      // 优先用滑块记录的时间，避免 seekTo 异步未完成导致读到错误位置
      final timeMs = _currentSliderTimeMs[cellIndex] ??
          controller?.value.position.inMilliseconds ??
          0;
      debugPrint('📸 设置封面: cell=$cellIndex, time=${timeMs}ms (slider=${_currentSliderTimeMs[cellIndex]}, ctrl=${controller?.value.position.inMilliseconds})');

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
