import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/image_transform.dart';

/// 可交互的图片组件 - 支持缩放、旋转、拖动
class InteractiveImageWidget extends StatefulWidget {
  final int index;
  final Uint8List? imageData;
  final bool isSelected;
  final ImageTransform transform;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Function(ImageTransform) onTransformChanged;

  const InteractiveImageWidget({
    super.key,
    required this.index,
    required this.imageData,
    required this.isSelected,
    required this.transform,
    required this.onTap,
    this.onLongPress,
    required this.onTransformChanged,
  });

  @override
  State<InteractiveImageWidget> createState() => _InteractiveImageWidgetState();
}

class _InteractiveImageWidgetState extends State<InteractiveImageWidget> {
  late ImageTransform _currentTransform;
  Offset _lastFocalPoint = Offset.zero;
  double _lastScale = 1.0;

  @override
  void initState() {
    super.initState();
    _currentTransform = widget.transform;
  }

  @override
  void didUpdateWidget(InteractiveImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.transform != oldWidget.transform) {
      _currentTransform = widget.transform;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageData == null) {
      return const SizedBox.shrink();
    }

    // 🔥 根据宽高比计算实际尺寸
    const baseWidth = 300.0;
    final actualHeight = baseWidth / _currentTransform.aspectRatio;

    return Positioned(
      left: _currentTransform.position.dx,
      top: _currentTransform.position.dy,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onScaleStart: widget.isSelected ? _handleScaleStart : null,
        onScaleUpdate: widget.isSelected ? _handleScaleUpdate : null,
        onScaleEnd: widget.isSelected ? _handleScaleEnd : null,
        behavior: HitTestBehavior.opaque,
        child: Transform.rotate(
          angle: _currentTransform.rotation,
          child: Transform.scale(
            scale: _currentTransform.scale,
            child: Container(
              width: baseWidth,
              height: actualHeight, // 🔥 使用计算出的高度
              decoration: BoxDecoration(
                border: widget.isSelected
                    ? Border.all(
                        color: const Color(0xFFFF85A2),
                        width: 3,
                      )
                    : null,
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF85A2).withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Image.memory(
                widget.imageData!,
                fit: BoxFit.cover, // 🔥 使用 cover 填充容器
                gaplessPlayback: true,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint;
    _lastScale = _currentTransform.scale;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      // 处理拖动（单指）
      if (details.pointerCount == 1) {
        _currentTransform = _currentTransform.copyWith(
          position: _currentTransform.position + 
                    (details.focalPoint - _lastFocalPoint),
        );
      }
      
      // 处理缩放（双指）
      if (details.pointerCount == 2) {
        _currentTransform = _currentTransform.copyWith(
          scale: (_lastScale * details.scale).clamp(0.5, 2.0),
        );
      }
      
      _lastFocalPoint = details.focalPoint;
    });
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    widget.onTransformChanged(_currentTransform);
  }
}
