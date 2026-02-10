import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/image_transform.dart';
import 'interactive_image_widget.dart';

/// 新的画布组件 - 支持自由布局和交互
class InteractiveCanvasWidget extends StatefulWidget {
  final List<Uint8List?> images;
  final Map<int, ImageTransform> transforms;
  final int? selectedIndex;
  final Function(int) onImageTap;
  final Function(int) onImageLongPress;
  final Function(int, ImageTransform) onTransformChanged;
  final VoidCallback onCanvasTap;

  const InteractiveCanvasWidget({
    super.key,
    required this.images,
    required this.transforms,
    this.selectedIndex,
    required this.onImageTap,
    required this.onImageLongPress,
    required this.onTransformChanged,
    required this.onCanvasTap,
  });

  @override
  State<InteractiveCanvasWidget> createState() => _InteractiveCanvasWidgetState();
}

class _InteractiveCanvasWidgetState extends State<InteractiveCanvasWidget> {
  final TransformationController _transformationController = TransformationController();
  double _canvasScale = 1.0;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 按 zIndex 排序图片
    final sortedIndices = List.generate(widget.images.length, (i) => i);
    sortedIndices.sort((a, b) {
      final transformA = widget.transforms[a] ?? ImageTransform();
      final transformB = widget.transforms[b] ?? ImageTransform();
      return transformA.zIndex.compareTo(transformB.zIndex);
    });

    return GestureDetector(
      onTap: widget.onCanvasTap,
      onDoubleTap: _resetCanvas,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.5,
        maxScale: 2.0,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        constrained: false,
        onInteractionUpdate: (details) {
          setState(() {
            _canvasScale = details.scale;
          });
        },
        child: Container(
          width: 1000,
          height: 2000,
          color: Colors.transparent,
          child: Stack(
            children: sortedIndices.map((index) {
              if (widget.images[index] == null) return const SizedBox.shrink();
              
              return InteractiveImageWidget(
                key: ValueKey('image_$index'),
                index: index,
                imageData: widget.images[index],
                isSelected: widget.selectedIndex == index,
                transform: widget.transforms[index] ?? ImageTransform(),
                onTap: () => widget.onImageTap(index),
                onLongPress: () => widget.onImageLongPress(index),
                onTransformChanged: (transform) {
                  widget.onTransformChanged(index, transform);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // 双击重置画布到 1:1 居中
  void _resetCanvas() {
    _transformationController.value = Matrix4.identity();
    setState(() {
      _canvasScale = 1.0;
    });
  }
}
