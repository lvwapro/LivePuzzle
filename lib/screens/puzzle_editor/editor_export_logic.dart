part of '../puzzle_editor_screen.dart';

/// 导出/保存相关逻辑
extension _EditorExportLogic on _PuzzleEditorScreenState {
  Future<void> savePuzzleToGallery() async {
    if (_selectedPhotos.isEmpty || _imageBlocks.isEmpty) return;

    final progressNotifier = ValueNotifier<double>(0.0);
    Timer? progressTimer;

    try {
      if (!mounted) return;

      final l10n = AppLocalizations.of(context)!;
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
              child: ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (context, progress, child) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
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
                      const SizedBox(height: 8),
                      Text(
                        progress < 1.0
                            ? l10n.exportingLivePhoto
                            : l10n.completed,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      final sw = Stopwatch()..start();

      final isLongImageLayout = _currentLayout?.id == 'long_horizontal' ||
          _currentLayout?.id == 'long_vertical';
      final layoutConfig = {
        'canvasWidth': _canvasConfig.width,
        'canvasHeight': _canvasConfig.height,
        'isLongImage': isLongImageLayout,
        'blocks': _imageBlocks
            .map((block) => {
                  'x': block.x,
                  'y': block.y,
                  'width': block.width,
                  'height': block.height,
                  'scale': block.scale,
                  'offsetX': block.offsetX,
                  'offsetY': block.offsetY,
                })
            .toList(),
      };

      final coverTimes = List<int>.generate(
        _selectedPhotos.length,
        (i) => _coverFrameTime[i] ?? 0,
      );
      final assetIds = _selectedPhotos.map((p) => p.id).toList();

      // 平滑渐进动画：每 200ms 递增，逐步逼近 90%
      progressTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        final current = progressNotifier.value;
        if (current < 0.9) {
          progressNotifier.value = current + (0.9 - current) * 0.06;
        }
      });

      // 并行：导出 + 预构建缩略图
      final exportFuture = LivePhotoBridge.createLivePhotoHardware(
        assetIds: assetIds,
        layoutConfig: layoutConfig,
        coverTimes: coverTimes,
      );
      final thumbnailFuture = _buildCompositeThumbnail();

      final results = await Future.wait([exportFuture, thumbnailFuture]);
      final success = results[0] as bool;
      final puzzleThumbnail = (results[1] as Uint8List?) ?? _photoThumbnails[0];

      progressTimer.cancel();
      debugPrint('⏱️ 导出完成，总耗时 ${sw.elapsedMilliseconds}ms');

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        if (success) {
          final photoIds = _selectedPhotos.map((p) => p.id).toList();
          final coverMs = List<int>.generate(
            _selectedPhotos.length,
            (i) => _coverFrameTime[i] ?? -1,
          );
          final blockTransforms = _imageBlocks
              .map((b) => {
                    'layoutBlockId': b.layoutBlockId,
                    'offsetX': b.offsetX,
                    'offsetY': b.offsetY,
                    'scale': b.scale,
                  })
              .toList();
          final history = PuzzleHistory(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            photoIds: photoIds,
            createdAt: DateTime.now(),
            thumbnail: puzzleThumbnail,
            photoCount: _selectedPhotos.length,
            lastLayoutId: _currentLayout?.id,
            lastRatio: _canvasConfig.ratio,
            lastCoverFrameTimeMs: coverMs,
            lastBlockTransforms: blockTransforms,
          );
          // 不等待历史记录写入，立即跳转
          ref.read(puzzleHistoryProvider.notifier).addHistory(history);

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => CompletionScreen(
                thumbnail: puzzleThumbnail,
                photoCount: _selectedPhotos.length,
                imageAspectRatio:
                    _canvasConfig.width / _canvasConfig.height,
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
      progressTimer?.cancel();
      progressNotifier.dispose();
    }
  }

  Future<Uint8List?> _buildCompositeThumbnail() async {
    if (_imageBlocks.isEmpty) return null;
    const double maxSide = 800.0;
    final ratio = _canvasConfig.width / _canvasConfig.height;
    final double canvasW = ratio >= 1.0 ? maxSide : maxSide * ratio;
    final double canvasH = ratio >= 1.0 ? maxSide / ratio : maxSide;

    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, Rect.fromLTWH(0, 0, canvasW, canvasH));
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
          final offsetX =
              (block.offsetX / _canvasConfig.width) * srcW;
          final cropX =
              ((srcW - cropW) / 2 - offsetX).clamp(0.0, srcW - cropW);
          srcRect = Rect.fromLTWH(cropX, 0, cropW, srcH);
        } else {
          final cropH = srcW / dstAspect;
          final offsetY =
              (block.offsetY / _canvasConfig.height) * srcH;
          final cropY =
              ((srcH - cropH) / 2 - offsetY).clamp(0.0, srcH - cropH);
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
    final finalImage =
        await picture.toImage(canvasW.round(), canvasH.round());
    final byteData =
        await finalImage.toByteData(format: ui.ImageByteFormat.png);
    finalImage.dispose();
    return byteData?.buffer.asUint8List();
  }
}
