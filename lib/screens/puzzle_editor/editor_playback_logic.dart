part of '../puzzle_editor_screen.dart';

/// 播放和帧提取相关逻辑
extension _EditorPlaybackLogic on _PuzzleEditorScreenState {
  Future<void> preExtractAllVideoFrames() async {
    for (int i = 0; i < _selectedPhotos.length; i++) {
      if (!mounted) return;
      if (_videoFrames.containsKey(i)) continue;
      await extractVideoFrames(i);
    }
    if (mounted) {
      debugPrint(
          '✅ 所有视频帧预提取完成 (${_videoFrames.length}/${_selectedPhotos.length})');
    }
  }

  Future<void> extractVideoFrames(int cellIndex) async {
    await initVideoPlayer(cellIndex);

    if (_videoFrames.containsKey(cellIndex)) return;

    final asset = _selectedPhotos[cellIndex];
    try {
      final isLive = await LivePhotoManager.isLivePhoto(asset);
      if (!isLive) return;

      final videoPath = _videoPaths[cellIndex];
      if (videoPath == null || videoPath.isEmpty) {
        debugPrint('⚠️ 视频路径为空，无法提取帧');
        return;
      }

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

      if (frames.isNotEmpty) {
        if (mounted) {
          setState(() {
            _videoFrames[cellIndex] = frames;
          });
          debugPrint(
              '✅ Live Photo $cellIndex 提取了 ${frames.length} 帧');
        }
      }
    } catch (e) {
      debugPrint('❌ 提取 Live Photo 帧失败: $e');
    }
  }

  void onAnimationTick() {
    if (!_isPlayingLivePuzzle) return;
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
          newData = _coverFrames[i] ?? _photoThumbnails[i];
        } else {
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

  Future<void> playLivePuzzle() async {
    if (_animationController == null || _animation == null) return;

    if (_isPlayingLivePuzzle) {
      debugPrint('⏸️ 停止播放 Live Puzzle');
      setState(() {
        _isPlayingLivePuzzle = false;
        restoreImageBlocksToCovers();
      });
      _animationController?.stop();
      _animationController?.reset();
      return;
    }

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
            return extractVideoFrames(i);
          }
          return Future.value();
        }),
      );

      int successCount = 0;
      for (int i = 0; i < _selectedPhotos.length; i++) {
        if (_videoFrames.containsKey(i) && _videoFrames[i]!.isNotEmpty) {
          successCount++;
        }
      }
      debugPrint(
          '✅ 提取完成: $successCount/${_selectedPhotos.length} 个视频');

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
}
