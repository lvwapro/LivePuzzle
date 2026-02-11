import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/canvas_config.dart';
import '../../models/image_block.dart';

/// 数据驱动画布组件
/// - Listener 处理平移/缩放（不参与手势竞技场，不拦截子组件的 tap）
/// - GestureDetector 处理点击（在手势竞技场中正常工作）
/// - OverflowBox 确保画布可以溢出视口但 hitTest 正确
/// - LayoutBuilder 计算初始变换，避免闪跳
class DataDrivenCanvas extends StatefulWidget {
  final CanvasConfig canvasConfig;
  final List<ImageBlock> imageBlocks;
  final String? selectedBlockId;
  final Function(String blockId) onBlockTap;
  final Function(String blockId, ImageBlock updatedBlock) onBlockChanged;
  final VoidCallback onCanvasTap;

  const DataDrivenCanvas({
    super.key,
    required this.canvasConfig,
    required this.imageBlocks,
    this.selectedBlockId,
    required this.onBlockTap,
    required this.onBlockChanged,
    required this.onCanvasTap,
  });

  @override
  State<DataDrivenCanvas> createState() => _DataDrivenCanvasState();
}

class _DataDrivenCanvasState extends State<DataDrivenCanvas> {
  // 画布变换
  Offset _translation = Offset.zero;
  double _scale = 1.0;
  bool _needsRecenter = true;

  // 手指追踪（Listener 不参与手势竞技场）
  final Map<int, Offset> _pointers = {};
  Offset? _lastMidpoint;
  double? _lastPointerDistance;
  bool _hasMoved = false;

  @override
  void didUpdateWidget(DataDrivenCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canvasConfig != widget.canvasConfig ||
        oldWidget.imageBlocks.length != widget.imageBlocks.length) {
      _needsRecenter = true;
    }
  }

  /// 直接计算居中变换（不调用 setState，可在 build 中使用）
  void _computeCenter(double viewportWidth, double viewportHeight) {
    final cw = widget.canvasConfig.width;
    final ch = widget.canvasConfig.height;
    if (cw <= 0 || ch <= 0) return;

    final targetScale = math.min(viewportWidth / cw, viewportHeight / ch) * 0.9;
    _scale = targetScale;
    _translation = Offset(
      (viewportWidth - cw * targetScale) / 2,
      (viewportHeight - ch * targetScale) / 2,
    );
  }

  /// 通过 setState 重新居中（用于双击重置）
  void _resetView() {
    if (!mounted) return;
    final rb = context.findRenderObject() as RenderBox?;
    if (rb == null || !rb.hasSize) return;
    setState(() {
      _computeCenter(rb.size.width, rb.size.height);
    });
  }

  // ---- 指针事件（平移 & 缩放）----

  Offset _getMidpoint() {
    if (_pointers.isEmpty) return Offset.zero;
    return _pointers.values.reduce((a, b) => a + b) / _pointers.length.toDouble();
  }

  double _getPointerDistance() {
    if (_pointers.length < 2) return 0;
    final v = _pointers.values.toList();
    return (v[0] - v[1]).distance;
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    _lastMidpoint = _getMidpoint();
    if (_pointers.length >= 2) _lastPointerDistance = _getPointerDistance();
    _hasMoved = false;
  }

  void _onPointerMove(PointerMoveEvent e) {
    _pointers[e.pointer] = e.position;
    final mid = _getMidpoint();

    // 超过 8px 才算真正移动
    if (!_hasMoved && _lastMidpoint != null) {
      if ((mid - _lastMidpoint!).distance > 8) _hasMoved = true;
    }
    if (!_hasMoved) return;

    setState(() {
      if (_lastMidpoint != null) _translation += (mid - _lastMidpoint!);
      if (_pointers.length >= 2 && _lastPointerDistance != null && _lastPointerDistance! > 0) {
        final d = _getPointerDistance();
        _scale = (_scale * d / _lastPointerDistance!).clamp(0.01, 20.0);
        _lastPointerDistance = d;
      }
    });
    _lastMidpoint = mid;
  }

  void _onPointerUp(PointerUpEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isEmpty) {
      _lastMidpoint = null;
      _lastPointerDistance = null;
    } else {
      _lastMidpoint = _getMidpoint();
      if (_pointers.length >= 2) _lastPointerDistance = _getPointerDistance();
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isEmpty) { _lastMidpoint = null; _lastPointerDistance = null; }
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final sortedBlocks = List<ImageBlock>.from(widget.imageBlocks)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    final cw = widget.canvasConfig.width;
    final ch = widget.canvasConfig.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 首次 / 布局变更时 → 同步计算居中（无闪跳）
        if (_needsRecenter && constraints.maxWidth > 0 && constraints.maxHeight > 0) {
          _computeCenter(constraints.maxWidth, constraints.maxHeight);
          _needsRecenter = false;
        }

        // Listener 处理平移/缩放（不参与手势竞技场 → 不拦截子组件 tap）
        return Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          behavior: HitTestBehavior.translucent,
          child: ClipRect(
            child: Stack(
              children: [
                // ━━━ 层 1：背景（捕获画布外的点击 & 双击重置）━━━
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      if (!_hasMoved) {
                        print('🎯 Background tapped → deselect');
                        widget.onCanvasTap();
                      }
                    },
                    onDoubleTap: () {
                      print('🎯 Double tap → reset view');
                      _resetView();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(color: const Color(0xFFF5F5F5)),
                  ),
                ),

                // ━━━ 层 2：画布（OverflowBox 允许溢出但 hitTest 正确）━━━
                Positioned.fill(
                  child: OverflowBox(
                    maxWidth: double.infinity,
                    maxHeight: double.infinity,
                    alignment: Alignment.topLeft,
                    child: Transform(
                      transform: Matrix4.identity()
                        ..translate(_translation.dx, _translation.dy)
                        ..scale(_scale, _scale, 1.0),
                      child: Container(
                        width: cw,
                        height: ch,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: sortedBlocks.map((block) {
                            final selected = widget.selectedBlockId == block.id;
                            final abs = block.toAbsolute(cw, ch);

                            return Positioned(
                              left: abs.x,
                              top: abs.y,
                              child: GestureDetector(
                                onTap: () {
                                  if (!_hasMoved) {
                                    print('🎯 Image tapped: ${block.id}');
                                    widget.onBlockTap(block.id);
                                  }
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  width: abs.width,
                                  height: abs.height,
                                  decoration: selected
                                      ? BoxDecoration(
                                          border: Border.all(
                                            color: const Color(0xFFFF85A2),
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFFF85A2).withValues(alpha: 0.4),
                                              blurRadius: 12,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        )
                                      : null,
                                  child: abs.imageData != null
                                      ? Image.memory(
                                          abs.imageData!,
                                          fit: BoxFit.cover,
                                          gaplessPlayback: true,
                                          filterQuality: FilterQuality.high,
                                        )
                                      : const Center(
                                          child: Icon(Icons.image, color: Colors.grey),
                                        ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
