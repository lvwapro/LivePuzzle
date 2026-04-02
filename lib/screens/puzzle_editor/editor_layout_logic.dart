part of '../puzzle_editor_screen.dart';

extension _EditorLayoutLogic on _PuzzleEditorScreenState {
  /// 根据图片数量确定初始布局（1张=1:1, 2张=3:4上下, 3张=9:16上下, 4-9张=长图纵向）
  (CanvasConfig, LayoutTemplate) getInitialLayout(int photoCount) {
    if (photoCount == 1) {
      return (
        CanvasConfig.fromRatio('1:1'),
        LayoutTemplate.presetLayouts.firstWhere((t) => t.id == 'single')
      );
    } else if (photoCount == 2) {
      return (
        CanvasConfig.fromRatio('3:4'),
        LayoutTemplate.presetLayouts.firstWhere((t) => t.id == 'grid_2x1')
      );
    } else if (photoCount == 3) {
      return (
        CanvasConfig.fromRatio('9:16'),
        LayoutTemplate.presetLayouts.firstWhere((t) => t.id == 'grid_3x1')
      );
    } else {
      return (
        CanvasConfig.fromRatio('1:1'),
        LayoutTemplate.getLongImageLayouts(photoCount)
            .firstWhere((t) => t.id == 'long_vertical')
      );
    }
  }

  /// 根据 id 和图片数量查找布局模板（预设或长图）
  LayoutTemplate? findTemplateById(String id, int photoCount) {
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

  /// 应用布局（使用新的数据驱动系统）
  Future<void> applyLayout(CanvasConfig canvas, LayoutTemplate template) async {
    if (_selectedPhotos.isEmpty) return;

    final List<Uint8List> images = [];
    for (int i = 0; i < _selectedPhotos.length; i++) {
      final imageData = _coverFrames[i] ?? _photoThumbnails[i];
      if (imageData != null) {
        images.add(imageData);
      }
    }

    if (images.isEmpty) return;

    final isLongImage =
        template.id == 'long_horizontal' || template.id == 'long_vertical';

    if (isLongImage) {
      final (longCanvas, longBlocks) =
          await calculateLongImageCanvasAndBlocks(template, images);
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

    setState(() {
      _canvasConfig = canvas;
      _currentLayout = template;
    });

    final aspectRatios = <double>[];
    for (final imgData in images) {
      try {
        final codec = await ui.instantiateImageCodec(imgData);
        final frame = await codec.getNextFrame();
        aspectRatios.add(frame.image.width / frame.image.height);
        frame.image.dispose();
      } catch (_) {
        aspectRatios.add(1.0);
      }
    }

    setState(() {
      _canvasConfig = canvas;
      _currentLayout = template;

      _imageBlocks = LayoutEngine.calculateLayout(
        canvas: canvas,
        template: template,
        images: images,
        spacing: _spacing,
      );

      for (int i = 0;
          i < _imageBlocks.length && i < aspectRatios.length;
          i++) {
        _imageBlocks[i] =
            _imageBlocks[i].copyWith(imageAspectRatio: aspectRatios[i]);
      }

      _selectedBlockId = null;
      _editorState = EditorState.global;
    });
  }

  /// 计算长图拼接的画布尺寸和比例分块（基于每张图片的真实尺寸）
  Future<(CanvasConfig, List<ImageBlock>)> calculateLongImageCanvasAndBlocks(
    LayoutTemplate template,
    List<Uint8List> images,
  ) async {
    if (images.isEmpty) {
      return (CanvasConfig.fromRatio('1:1'), <ImageBlock>[]);
    }

    final isHorizontal = template.id == 'long_horizontal';

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
      final unifiedH = imageSizes.map((s) => s.height).reduce(math.max);
      final scaledWidths =
          imageSizes.map((s) => (s.width / s.height) * unifiedH).toList();
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

      debugPrint(
          '📐 横向长图: ${totalWidth.toInt()}×${unifiedH.toInt()}, ${blocks.length} 块');
    } else {
      final unifiedW = imageSizes.map((s) => s.width).reduce(math.max);
      final scaledHeights =
          imageSizes.map((s) => (s.height / s.width) * unifiedW).toList();
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

      debugPrint(
          '📐 纵向长图: ${unifiedW.toInt()}×${totalHeight.toInt()}, ${blocks.length} 块');
    }

    return (canvas, blocks);
  }

  /// 更新间距并重新计算布局（保留图片数据和缩放/偏移）
  void _updateSpacing(double newSpacing) {
    if (_currentLayout == null || _imageBlocks.isEmpty) return;
    if (_currentLayout!.id.startsWith('long_')) return;

    final images =
        _imageBlocks.map((b) => b.imageData).whereType<Uint8List>().toList();
    if (images.isEmpty) return;

    setState(() {
      _spacing = newSpacing;
      final newBlocks = LayoutEngine.calculateLayout(
        canvas: _canvasConfig,
        template: _currentLayout!,
        images: images,
        spacing: newSpacing,
      );

      for (int i = 0; i < newBlocks.length && i < _imageBlocks.length; i++) {
        newBlocks[i] = newBlocks[i].copyWith(
          imageAspectRatio: _imageBlocks[i].imageAspectRatio,
          scale: _imageBlocks[i].scale,
          offsetX: _imageBlocks[i].offsetX,
          offsetY: _imageBlocks[i].offsetY,
        );
      }
      _imageBlocks = newBlocks;
    });
  }
}
