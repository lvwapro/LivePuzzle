part of '../puzzle_editor_screen.dart';

/// 导出/保存相关逻辑
extension _EditorExportLogic on _PuzzleEditorScreenState {
  // 🔥 保存拼图到图库（Live Photo 格式）- 🚀 硬件加速版本
  Future<void> savePuzzleToGallery() async {
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

      if (_imageBlocks.isNotEmpty) {
        debugPrint('🚀 使用硬件加速模式导出...');

        messageNotifier.value =
            AppLocalizations.of(context)!.loadingVideoResources;
        progressNotifier.value = 0.05;

        await Future.delayed(const Duration(milliseconds: 100));

        messageNotifier.value =
            AppLocalizations.of(context)!.preparingLayout;
        progressNotifier.value = 0.1;

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

        final canvasH = _canvasConfig.height;
        final canvasW = _canvasConfig.width;
        debugPrint(
            '🔍 画布: $canvasW×$canvasH ratio=${_canvasConfig.ratio} 高>宽=${canvasH > canvasW}');
        for (int i = 0; i < _imageBlocks.length; i++) {
          final b = _imageBlocks[i];
          debugPrint(
              '🔍 Block[$i]: x=${b.x.toStringAsFixed(3)} y=${b.y.toStringAsFixed(3)} w=${b.width.toStringAsFixed(3)} h=${b.height.toStringAsFixed(3)} scale=${b.scale} offsetX=${b.offsetX} offsetY=${b.offsetY}');
        }

        final coverTimes = List<int>.generate(
          _selectedPhotos.length,
          (i) => _coverFrameTime[i] ?? 0,
        );

        final assetIds = _selectedPhotos.map((p) => p.id).toList();

        messageNotifier.value =
            AppLocalizations.of(context)!.hardwareEncoding;
        progressNotifier.value = 0.2;

        final success = await LivePhotoBridge.createLivePhotoHardware(
          assetIds: assetIds,
          layoutConfig: layoutConfig,
          coverTimes: coverTimes,
        );

        progressNotifier.value = 1.0;
        messageNotifier.value = AppLocalizations.of(context)!.completed;

        debugPrint(
            '⏱️ 硬件加速导出完成，总耗时 ${sw.elapsedMilliseconds}ms');

        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();

          if (success) {
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
            await ref
                .read(puzzleHistoryProvider.notifier)
                .addHistory(history);

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
        return;
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
