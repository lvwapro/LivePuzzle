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
// 导入拆分的组件
import 'puzzle_editor/editor_header_widget.dart';
import 'puzzle_editor/video_frame_selector_widget.dart';
import 'puzzle_editor/dynamic_toolbar.dart';
import 'puzzle_editor/layout_selection_panel.dart';
import 'puzzle_editor/data_driven_canvas.dart';
import 'package:live_puzzle/l10n/app_localizations.dart';

part 'puzzle_editor/editor_export_logic.dart';
part 'puzzle_editor/editor_playback_logic.dart';
part 'puzzle_editor/editor_cover_logic.dart';

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
    _animationController!.addListener(onAnimationTick);

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
            restoreImageBlocksToCovers();
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
          _animationController!.addListener(onAnimationTick);
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
                  restoreImageBlocksToCovers();
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
            restoreCoverFramesFromSavedTimes();
          }

          // 后台预提取所有视频帧（不阻塞UI）
          preExtractAllVideoFrames();
        }
      }
    });
  }

  void _handleCanvasTap() {
    revertFrameEdit();
    setState(() {
      _selectedCellIndex = -1;
      _selectedBlockId = null;
      _editorState = EditorState.global;
      _selectedGlobalTool = null;
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
    // TODO: 在新画布系统中实现旋转
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('旋转功能开发中')),
    );
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
        revertFrameEdit();

        // 保存当前图片数据，用于取消时恢复
        if (blockIndex >= 0 && blockIndex < _imageBlocks.length) {
          _preEditImageData[blockIndex] = _imageBlocks[blockIndex].imageData;
        }

        setState(() {
          _selectedBlockId = blockId;
          _editorState = EditorState.single;
          if (blockIndex >= 0) {
            _selectedCellIndex = blockIndex;
            initVideoPlayer(blockIndex);
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
                  onDone: savePuzzleToGallery,
                  onPlayLive:
                      _selectedPhotos.isNotEmpty ? playLivePuzzle : null,
                  isPlayingLive: _isPlayingLivePuzzle,
                ),

                // 拼图预览画布
                Expanded(
                  child: Container(
                    color: const Color(0xFFF5F5F5),
                    child: _buildNewCanvas(),
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
                      throttledExtractFrame(_selectedCellIndex, timeMs);
                    },
                    onConfirm: () => handleSetCover(_selectedCellIndex),
                    onCancel: () {
                      // 取消：恢复原图并取消选中
                      revertFrameEdit();
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

}
