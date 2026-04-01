part of '../puzzle_editor_screen.dart';

/// 封面帧和视频播放器相关逻辑
extension _EditorCoverLogic on _PuzzleEditorScreenState {
  Future<void> restoreCoverFramesFromSavedTimes() async {
    if (_restoreHistory == null) return;
    final coverMs = _restoreHistory!.lastCoverFrameTimeMs;
    if (coverMs == null || coverMs.isEmpty) return;

    for (int i = 0; i < coverMs.length && i < _selectedPhotos.length; i++) {
      final timeMs = coverMs[i];
      if (timeMs < 0) continue;

      final videoPath = _videoPaths[i];
      if (videoPath == null || videoPath.isEmpty) continue;

      try {
        final framePath =
            await LivePhotoBridge.extractFrame(videoPath, timeMs);
        if (framePath != null) {
          final file = File(framePath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            if (mounted) {
              setState(() {
                _coverFrames[i] = bytes;
                _coverFrameTime[i] = timeMs;
                _currentDisplayImages[i] = bytes;
                if (i < _imageBlocks.length) {
                  _imageBlocks[i] =
                      _imageBlocks[i].copyWith(imageData: bytes);
                }
              });
            }
            await file.delete();
          }
        }
      } catch (e) {
        debugPrint('⚠️ 恢复封面帧 $i 失败: $e');
      }
    }
  }

  Future<void> initVideoPlayer(int cellIndex) async {
    if (_videoControllers.containsKey(cellIndex) &&
        _videoControllers[cellIndex] != null) return;

    final asset = _selectedPhotos[cellIndex];
    try {
      final videoFile = await LivePhotoManager.getVideoFile(asset);
      if (videoFile == null) return;

      _videoPaths[cellIndex] = videoFile.path;

      final durationMs =
          await LivePhotoBridge.getVideoDuration(asset.id);
      if (mounted) {
        setState(() {
          _videoDurations[cellIndex] = durationMs;
          if (durationMs > _maxDurationMs) {
            _maxDurationMs = durationMs;
          }
        });
      }

      final controller = VideoPlayerController.file(videoFile);
      await controller.initialize();
      if (mounted) {
        setState(() {
          _videoControllers[cellIndex] = controller;
        });
      }
    } catch (e) {
      debugPrint('⚠️ 初始化视频播放器失败: $e');
    }
  }

  Future<Uint8List?> captureVideoFrame(int cellIndex) async {
    final videoPath = _videoPaths[cellIndex];
    if (videoPath == null) return null;

    final controller = _videoControllers[cellIndex];
    if (controller == null || !controller.value.isInitialized) return null;

    try {
      final timeMs = _currentSliderTimeMs[cellIndex] ??
          controller.value.position.inMilliseconds;
      final framePath =
          await LivePhotoBridge.extractFrame(videoPath, timeMs);
      if (framePath != null) {
        final file = File(framePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          await file.delete();
          return bytes;
        }
      }
    } catch (e) {
      debugPrint('⚠️ 截取视频帧失败: $e');
    }
    return null;
  }

  void revertFrameEdit() {
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

  void throttledExtractFrame(int cellIndex, int timeMs) {
    if (!mounted || cellIndex < 0 || cellIndex >= _imageBlocks.length) return;

    _currentSliderTimeMs[cellIndex] = timeMs;

    final frames = _videoFrames[cellIndex];
    if (frames != null && frames.isNotEmpty) {
      final videoDurationMs = _videoDurations[cellIndex] ?? 2000;
      final videoProgress =
          (timeMs / videoDurationMs).clamp(0.0, 1.0);
      final frameIndex = (videoProgress * (frames.length - 1))
          .round()
          .clamp(0, frames.length - 1);

      setState(() {
        _imageBlocks[cellIndex] =
            _imageBlocks[cellIndex].copyWith(imageData: frames[frameIndex]);
      });
      return;
    }

    _frameExtractTimer?.cancel();
    _frameExtractTimer = Timer(const Duration(milliseconds: 80), () async {
      if (!mounted || cellIndex >= _imageBlocks.length) return;
      final videoPath = _videoPaths[cellIndex];
      if (videoPath == null) return;
      try {
        final framePath =
            await LivePhotoBridge.extractFrame(videoPath, timeMs);
        if (framePath != null && mounted) {
          final file = File(framePath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            setState(() {
              _imageBlocks[cellIndex] =
                  _imageBlocks[cellIndex].copyWith(imageData: bytes);
            });
            await file.delete();
          }
        }
      } catch (e) {
        debugPrint('⚠️ 原生 extractFrame 失败: $e');
      }
    });
  }

  Future<void> handleSetCover(int cellIndex) async {
    _frameExtractTimer?.cancel();
    final frameData = await captureVideoFrame(cellIndex);

    if (frameData != null) {
      final controller = _videoControllers[cellIndex];
      final timeMs = _currentSliderTimeMs[cellIndex] ??
          controller?.value.position.inMilliseconds ??
          0;
      debugPrint(
          '📸 设置封面: cell=$cellIndex, time=${timeMs}ms (slider=${_currentSliderTimeMs[cellIndex]}, ctrl=${controller?.value.position.inMilliseconds})');

      setState(() {
        _coverFrames[cellIndex] = frameData;
        _coverFrameTime[cellIndex] = timeMs;
        _currentDisplayImages[cellIndex] = frameData;
        if (cellIndex < _imageBlocks.length) {
          _imageBlocks[cellIndex] = _imageBlocks[cellIndex].copyWith(
            imageData: frameData,
          );
        }
      });

      _preEditImageData.remove(cellIndex);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.frameSetSuccess} (${(timeMs / 1000).toStringAsFixed(2)}s)',
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
          SnackBar(
            content: Text(AppLocalizations.of(context)!.frameSetFailed),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
