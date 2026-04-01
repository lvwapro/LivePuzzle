import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_puzzle/providers/photo_provider.dart';
import 'package:live_puzzle/providers/puzzle_history_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:live_puzzle/models/puzzle_history.dart';
import 'package:live_puzzle/screens/completion_screen.dart';
import 'package:live_puzzle/services/live_photo_manager.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:live_photo_bridge/live_photo_bridge.dart';
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
part 'puzzle_editor/editor_layout_logic.dart';
part 'puzzle_editor/editor_session_load.dart';

/// 拼图编辑器页面 - Seamless Puzzle风格
class PuzzleEditorScreen extends ConsumerStatefulWidget {
  const PuzzleEditorScreen({super.key});

  @override
  ConsumerState<PuzzleEditorScreen> createState() => _PuzzleEditorScreenState();
}

class _PuzzleEditorScreenState extends ConsumerState<PuzzleEditorScreen>
    with TickerProviderStateMixin {
  // 🔥 基础状态
  bool _isInitialLoading = true;
  int _selectedCellIndex = -1; // -1 表示未选中任何图片
  List<AssetEntity> _selectedPhotos = [];
  final Map<int, Uint8List?> _photoThumbnails = {};

  EditorState _editorState = EditorState.global;

  // 🔥 新的数据驱动布局系统
  CanvasConfig _canvasConfig = CanvasConfig.fromRatio('1:1'); // 画布配置
  LayoutTemplate? _currentLayout; // 当前布局模板
  List<ImageBlock> _imageBlocks = []; // 图片块列表（使用相对坐标0-1）
  String? _selectedBlockId; // 选中的图片块ID

  // 🔥 视频播放器相关
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
  bool _isPlayingLivePuzzle = false;

  // 🔥 当前显示的图片（用于网格显示）
  final Map<int, Uint8List?> _currentDisplayImages = {};

  // 🔥 帧编辑：进入帧选择时保存原始图片，取消时恢复
  final Map<int, Uint8List?> _preEditImageData = {};
  Timer? _frameExtractTimer;
  Timer? _playbackTimer;

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
    _animationController!.addListener(onAnimationTick);
    attachAnimationCompletionListener();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadSelectedPhotos();
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
    _playbackTimer?.cancel();
    _animationController?.dispose();
    for (final controller in _videoControllers.values) {
      controller?.dispose();
    }
    super.dispose();
  }

  void _handleCanvasTap() {
    revertFrameEdit();
    setState(() {
      _selectedCellIndex = -1;
      _selectedBlockId = null;
      _editorState = EditorState.global;
    });
  }


  // 🔥 构建新画布（自由交互）
  Widget _buildNewCanvas() {
    if (_isInitialLoading || _selectedPhotos.isEmpty || _imageBlocks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF85A2),
          strokeWidth: 3,
        ),
      );
    }

    final isFrameEditing = _editorState == EditorState.single &&
        _selectedCellIndex >= 0 &&
        !_isPlayingLivePuzzle &&
        _videoControllers.containsKey(_selectedCellIndex) &&
        _videoControllers[_selectedCellIndex] != null;

    return DataDrivenCanvas(
      canvasConfig: _canvasConfig,
      imageBlocks: _imageBlocks,
      selectedBlockId: _selectedBlockId,
      isPlaying: _isPlayingLivePuzzle,
      videoControllers: _isPlayingLivePuzzle ? _videoControllers : null,
      frameEditingBlockIdx: isFrameEditing ? _selectedCellIndex : null,
      frameEditingController:
          isFrameEditing ? _videoControllers[_selectedCellIndex] : null,
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

                // 工具栏/布局面板（加载中/帧选择器弹出时隐藏）
                if (!_isInitialLoading && !_isPlayingLivePuzzle && !hasVideoReady)
                  if (_editorState == EditorState.global)
                    SizedBox(
                      height: 280,
                      child: LayoutSelectionPanel(
                        photoCount: _selectedPhotos.length,
                        selectedLayoutId: _currentLayout?.id,
                        selectedRatio: _canvasConfig.ratio,
                        onLayoutSelected: (canvas, template) {
                          applyLayout(canvas, template);
                        },
                      ),
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
                      _currentSliderTimeMs[_selectedCellIndex] = timeMs;
                      _videoControllers[_selectedCellIndex]?.seekTo(
                        Duration(milliseconds: timeMs),
                      );
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
