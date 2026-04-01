part of '../puzzle_editor_screen.dart';

/// 播放和帧提取相关逻辑
extension _EditorPlaybackLogic on _PuzzleEditorScreenState {
  /// 后台预初始化所有视频播放器（不再预提取帧）
  Future<void> preInitAllVideoPlayers() async {
    for (int i = 0; i < _selectedPhotos.length; i++) {
      if (!mounted) return;
      await initVideoPlayer(i);
    }
    if (mounted) {
      debugPrint(
          '✅ 所有视频播放器初始化完成 (${_videoControllers.length}/${_selectedPhotos.length})');
    }
  }

  /// 按需提取帧（仅用于封面帧选择时的 fallback）
  Future<void> extractVideoFrames(int cellIndex) async {
    await initVideoPlayer(cellIndex);

    if (_videoFrames.containsKey(cellIndex)) return;

    final asset = _selectedPhotos[cellIndex];
    try {
      final isLive = await LivePhotoManager.isLivePhoto(asset);
      if (!isLive) return;

      final videoPath = _videoPaths[cellIndex];
      if (videoPath == null || videoPath.isEmpty) return;

      final videoDurationMs = _videoDurations[cellIndex] ?? 2000;
      debugPrint(
          '🎞️ 开始提取 Live Photo 帧: $cellIndex, 时长: ${videoDurationMs}ms');

      final frames = <Uint8List>[];
      for (int i = 0; i < _PuzzleEditorScreenState.kTotalFrames; i++) {
        final progress = i / (_PuzzleEditorScreenState.kTotalFrames - 1);
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

      if (frames.isNotEmpty && mounted) {
        setState(() {
          _videoFrames[cellIndex] = frames;
        });
        debugPrint('✅ Live Photo $cellIndex 提取了 ${frames.length} 帧');
      }
    } catch (e) {
      debugPrint('❌ 提取 Live Photo 帧失败: $e');
    }
  }

  /// 播放时不再需要 onAnimationTick 做帧替换（保留接口以兼容 AnimationController.addListener）
  void onAnimationTick() {
    // VideoPlayer 模式下由原生视频解码驱动，无需手动替换帧
  }

  void restoreImageBlocksToCovers() {
    for (int i = 0;
        i < _imageBlocks.length && i < _selectedPhotos.length;
        i++) {
      final coverData = _coverFrames[i] ?? _photoThumbnails[i];
      if (coverData != null) {
        _imageBlocks[i] = _imageBlocks[i].copyWith(imageData: coverData);
      }
    }
  }

  void _stopAllVideoPlayers() {
    for (final controller in _videoControllers.values) {
      if (controller != null && controller.value.isInitialized) {
        controller.pause();
      }
    }
  }

  Future<void> playLivePuzzle() async {
    if (_isPlayingLivePuzzle) {
      debugPrint('⏸️ 停止播放 Live Puzzle');
      _stopAllVideoPlayers();
      _playbackTimer?.cancel();
      setState(() {
        _isPlayingLivePuzzle = false;
        restoreImageBlocksToCovers();
      });
      return;
    }

    // 确保所有视频播放器已初始化
    bool needsInit = false;
    for (int i = 0; i < _selectedPhotos.length; i++) {
      if (_videoControllers[i] == null ||
          !_videoControllers[i]!.value.isInitialized) {
        needsInit = true;
        break;
      }
    }

    if (needsInit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在准备视频，请稍候...'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFFF4D7D),
          ),
        );
      }
      await preInitAllVideoPlayers();
    }

    // 检查是否有可用的视频播放器
    int readyCount = 0;
    for (int i = 0; i < _selectedPhotos.length; i++) {
      final c = _videoControllers[i];
      if (c != null && c.value.isInitialized) {
        readyCount++;
      }
    }
    if (readyCount == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('没有可播放的视频'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    debugPrint('▶️ 开始播放 Live Puzzle (VideoPlayer 模式, $readyCount 路视频)');

    // 同步所有视频控制器：seekTo(0) + play
    for (int i = 0; i < _selectedPhotos.length; i++) {
      final c = _videoControllers[i];
      if (c != null && c.value.isInitialized) {
        await c.seekTo(Duration.zero);
      }
    }

    setState(() {
      _isPlayingLivePuzzle = true;
    });

    // 同时启动所有视频
    for (int i = 0; i < _selectedPhotos.length; i++) {
      final c = _videoControllers[i];
      if (c != null && c.value.isInitialized) {
        c.play();
      }
    }

    // 使用定时器在最长视频结束后自动停止
    _playbackTimer?.cancel();
    _playbackTimer = Timer(Duration(milliseconds: _maxDurationMs), () {
      if (!mounted || !_isPlayingLivePuzzle) return;
      _stopAllVideoPlayers();
      setState(() {
        _isPlayingLivePuzzle = false;
        restoreImageBlocksToCovers();
      });
      debugPrint('⏹️ 播放结束（定时停止）');
    });
  }
}
