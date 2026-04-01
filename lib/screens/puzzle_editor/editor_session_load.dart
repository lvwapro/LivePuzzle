part of '../puzzle_editor_screen.dart';

extension _EditorSessionLoad on _PuzzleEditorScreenState {
  /// 动画完成时恢复封面的监听器（initState 和重建 controller 时共用）
  void attachAnimationCompletionListener() {
    _animationController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _isPlayingLivePuzzle = false;
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

  Future<void> loadSelectedPhotos() async {
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

        final loadedIds = selectedAssets.map((a) => a.id).toList();
        CanvasConfig canvas;
        LayoutTemplate template;
        final useRestore = restore != null &&
            listEquals(restore.photoIds, loadedIds) &&
            restore.lastLayoutId != null &&
            restore.lastRatio != null;
        if (useRestore) {
          final t =
              findTemplateById(restore.lastLayoutId!, selectedAssets.length);
          if (t != null) {
            template = t;
            canvas = CanvasConfig.fromRatio(restore.lastRatio!);
          } else {
            final initial = getInitialLayout(selectedAssets.length);
            canvas = initial.$1;
            template = initial.$2;
          }
        } else {
          final initial = getInitialLayout(selectedAssets.length);
          canvas = initial.$1;
          template = initial.$2;
        }

        // 先赋值但不触发 setState，避免中间态闪烁
        _selectedPhotos = selectedAssets;
        _canvasConfig = canvas;
        _currentLayout = template;

        for (int i = 0; i < selectedAssets.length; i++) {
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

        int maxDurationMs = 2000;
        for (int i = 0; i < selectedAssets.length; i++) {
          final asset = selectedAssets[i];
          try {
            final durationMs =
                await LivePhotoBridge.getVideoDuration(asset.id);
            _videoDurations[i] = durationMs;
            if (durationMs > maxDurationMs) {
              maxDurationMs = durationMs;
            }
            debugPrint(
                '📹 Live Photo $i (${asset.id}) 时长: ${durationMs}ms');
          } catch (e) {
            _videoDurations[i] = 2000;
            debugPrint('Error getting duration: $e');
          }
        }

        _maxDurationMs = maxDurationMs;
        debugPrint('🎬 最长 Live Photo 时长: ${maxDurationMs}ms');

        if (mounted) {
          _animationController?.dispose();
          _animationController = AnimationController(
            duration: Duration(milliseconds: maxDurationMs),
            vsync: this,
          );
          _animationController!.addListener(onAnimationTick);
          attachAnimationCompletionListener();
        }

        final List<Uint8List> loadedThumbnails = [];
        for (int i = 0; i < _selectedPhotos.length; i++) {
          try {
            final thumbnail =
                await _selectedPhotos[i].thumbnailDataWithSize(
              const ThumbnailSize(1000, 1000),
              quality: 85,
            );
            if (thumbnail != null) {
              loadedThumbnails.add(thumbnail);
              _photoThumbnails[i] = thumbnail;
            }
          } catch (e) {
            debugPrint('Error loading thumbnail $i: $e');
          }
        }

        if (mounted &&
            loadedThumbnails.isNotEmpty &&
            _currentLayout != null) {
          await applyLayout(_canvasConfig, _currentLayout!);

          // 恢复区块变换（位移/缩放/槽位交换）
          if (useRestore && restore.lastBlockTransforms != null) {
            _restoreBlockTransforms(restore.lastBlockTransforms!);
          }

          // 先初始化播放器（获取 _videoPaths），再恢复封面帧
          await preInitAllVideoPlayers();

          final coverTimesToRestore = List<int>.generate(
            _selectedPhotos.length,
            (i) => _coverFrameTime[i] ?? -1,
          );
          final hasCoverTimes = coverTimesToRestore.any((t) => t >= 0);
          if (mounted && hasCoverTimes) {
            await restoreCoverFramesFromSavedTimes(coverTimesToRestore);
          }
        }

        // 所有初始化完成，一次性显示最终画面
        if (mounted) {
          setState(() {
            _isInitialLoading = false;
          });
        }
      }
    });
  }

  /// 从历史记录恢复每个区块的 layoutBlockId/offsetX/offsetY/scale
  void _restoreBlockTransforms(List<Map<String, dynamic>> transforms) {
    if (transforms.length != _imageBlocks.length) return;

    setState(() {
      for (int i = 0; i < transforms.length && i < _imageBlocks.length; i++) {
        final t = transforms[i];
        final savedSlot = t['layoutBlockId'] as String?;
        final currentSlot = _imageBlocks[i].layoutBlockId;

        // 如果 layoutBlockId 不同，需要找到对应的几何并交换
        if (savedSlot != null && savedSlot != currentSlot) {
          final targetIdx =
              _imageBlocks.indexWhere((b) => b.layoutBlockId == savedSlot);
          if (targetIdx >= 0 && targetIdx != i) {
            final srcBlock = _imageBlocks[i];
            final tgtBlock = _imageBlocks[targetIdx];
            _imageBlocks[i] = srcBlock.copyWith(
              x: tgtBlock.x,
              y: tgtBlock.y,
              width: tgtBlock.width,
              height: tgtBlock.height,
              layoutBlockId: tgtBlock.layoutBlockId,
            );
            _imageBlocks[targetIdx] = tgtBlock.copyWith(
              x: srcBlock.x,
              y: srcBlock.y,
              width: srcBlock.width,
              height: srcBlock.height,
              layoutBlockId: srcBlock.layoutBlockId,
            );
          }
        }

        _imageBlocks[i] = _imageBlocks[i].copyWith(
          offsetX: (t['offsetX'] as num?)?.toDouble() ?? 0,
          offsetY: (t['offsetY'] as num?)?.toDouble() ?? 0,
          scale: (t['scale'] as num?)?.toDouble() ?? 1.0,
        );
      }
    });
  }
}
