import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/canvas_config.dart';
import '../../models/image_block.dart';
import 'canvas_shared_edge.dart';
import 'canvas_image_block_widget.dart';
import 'canvas_edge_dividers.dart';

/// 数据驱动画布组件
class DataDrivenCanvas extends StatefulWidget {
  final CanvasConfig canvasConfig;
  final List<ImageBlock> imageBlocks;
  final String? selectedBlockId;
  final Function(String blockId) onBlockTap;
  final Function(String blockId, ImageBlock updatedBlock) onBlockChanged;
  final Function(String sourceId, String targetId) onBlockSwap;
  final Function(List<ImageBlock> updatedBlocks) onBlocksResized;
  final VoidCallback onCanvasTap;
  final bool isPlaying;
  final Map<int, VideoPlayerController?>? videoControllers;
  final int? frameEditingBlockIdx;
  final VideoPlayerController? frameEditingController;

  const DataDrivenCanvas({
    super.key,
    required this.canvasConfig,
    required this.imageBlocks,
    this.selectedBlockId,
    required this.onBlockTap,
    required this.onBlockChanged,
    required this.onBlockSwap,
    required this.onBlocksResized,
    required this.onCanvasTap,
    this.isPlaying = false,
    this.videoControllers,
    this.frameEditingBlockIdx,
    this.frameEditingController,
  });

  @override
  State<DataDrivenCanvas> createState() => _DataDrivenCanvasState();
}

class _DataDrivenCanvasState extends State<DataDrivenCanvas> {
  Offset _translation = Offset.zero;
  double _scale = 1.0;
  bool _needsRecenter = true;

  final Map<int, Offset> _pointers = {};
  Offset? _lastMidpoint;
  double? _lastPointerDistance;
  bool _hasMoved = false;

  // 图片拖动
  bool _isMovingImage = false;
  String? _movingBlockId;
  double _moveDeltaX = 0;
  double _moveDeltaY = 0;

  // 边缘拖动（调整占比）
  bool _isDraggingEdge = false;
  SharedEdge? _draggingEdge;
  double _edgeDragDelta = 0; // 相对坐标偏移

  @override
  void didUpdateWidget(DataDrivenCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canvasConfig != widget.canvasConfig ||
        oldWidget.imageBlocks.length != widget.imageBlocks.length) {
      _needsRecenter = true;
    }
  }

  void _computeCenter(double vw, double vh) {
    final cw = widget.canvasConfig.width;
    final ch = widget.canvasConfig.height;
    if (cw <= 0 || ch <= 0) return;
    final s = math.min(vw / cw, vh / ch) * 0.95;
    _scale = s;
    _translation = Offset((vw - cw * s) / 2, (vh - ch * s) / 2);
  }

  void _resetView() {
    if (!mounted) return;
    final rb = context.findRenderObject() as RenderBox?;
    if (rb == null || !rb.hasSize) return;
    setState(() => _computeCenter(rb.size.width, rb.size.height));
  }

  /// 检查屏幕坐标是否靠近选中图片的某条共享边，返回匹配的边
  SharedEdge? _findEdgeAtScreenPos(Offset screenPos) {
    if (widget.selectedBlockId == null) return null;

    final cw = widget.canvasConfig.width;
    final ch = widget.canvasConfig.height;
    final canvasX = (screenPos.dx - _translation.dx) / _scale;
    final canvasY = (screenPos.dy - _translation.dy) / _scale;
    final relX = canvasX / cw;
    final relY = canvasY / ch;

    final hitDistX = 20.0 / (_scale * cw);
    final hitDistY = 20.0 / (_scale * ch);

    final edges = findSelectedEdges(
        widget.imageBlocks, widget.selectedBlockId);
    for (final edge in edges) {
      if (edge.isVertical) {
        if ((relX - edge.position).abs() < hitDistX &&
            relY > -0.02 &&
            relY < 1.02) {
          return edge;
        }
      } else {
        if ((relY - edge.position).abs() < hitDistY &&
            relX > -0.02 &&
            relX < 1.02) {
          return edge;
        }
      }
    }
    return null;
  }

  bool _isDeltaWithinBounds() {
    if (_movingBlockId == null) return true;
    final idx = widget.imageBlocks.indexWhere((b) => b.id == _movingBlockId);
    if (idx < 0) return true;
    final block = widget.imageBlocks[idx];
    final cw = widget.canvasConfig.width;
    final ch = widget.canvasConfig.height;
    final abs = block.toAbsolute(cw, ch);
    return _moveDeltaX.abs() <= abs.width * 0.4 &&
        _moveDeltaY.abs() <= abs.height * 0.4;
  }

  String? _findBlockAtCanvasPos(double cx, double cy, {String? excludeId}) {
    final cw = widget.canvasConfig.width;
    final ch = widget.canvasConfig.height;
    for (final block in widget.imageBlocks) {
      if (block.id == excludeId) continue;
      final abs = block.toAbsolute(cw, ch);
      if (cx >= abs.x &&
          cx <= abs.x + abs.width &&
          cy >= abs.y &&
          cy <= abs.y + abs.height) {
        return block.id;
      }
    }
    return null;
  }

  // ---- 指针事件 ----

  Offset _getMidpoint() {
    if (_pointers.isEmpty) return Offset.zero;
    return _pointers.values.reduce((a, b) => a + b) /
        _pointers.length.toDouble();
  }

  double _getPointerDistance() {
    if (_pointers.length < 2) return 0;
    final v = _pointers.values.toList();
    return (v[0] - v[1]).distance;
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    _lastMidpoint = _getMidpoint();
    if (_pointers.length >= 2) _lastPointerDistance = _getPointerDistance();
    _hasMoved = false;

    // 检查是否点在共享边上
    if (_pointers.length == 1) {
      final edge = _findEdgeAtScreenPos(e.localPosition);
      if (edge != null) {
        _draggingEdge = edge;
        _edgeDragDelta = 0;
        _isDraggingEdge = false; // 等移动后再确认
        _movingBlockId = null;
        _isMovingImage = false;
        return;
      }
    }

    _draggingEdge = null;
    _isDraggingEdge = false;

    if (_pointers.length == 1 && widget.selectedBlockId != null) {
      _movingBlockId = widget.selectedBlockId;
      _moveDeltaX = 0;
      _moveDeltaY = 0;
    } else {
      _movingBlockId = null;
    }
    _isMovingImage = false;
  }

  void _onPointerMove(PointerMoveEvent e) {
    _pointers[e.pointer] = e.localPosition;
    final mid = _getMidpoint();

    if (!_hasMoved && _lastMidpoint != null) {
      if ((mid - _lastMidpoint!).distance > 8) {
        _hasMoved = true;
        if (_draggingEdge != null) {
          _isDraggingEdge = true;
        } else if (_movingBlockId != null && _pointers.length == 1) {
          _isMovingImage = true;
        }
      }
    }
    if (!_hasMoved) return;

    setState(() {
      if (_isDraggingEdge && _draggingEdge != null && _lastMidpoint != null) {
        // ━━━ 拖动共享边 ━━━
        final cw = widget.canvasConfig.width;
        final ch = widget.canvasConfig.height;
        final screenDelta = mid - _lastMidpoint!;
        if (_draggingEdge!.isVertical) {
          _edgeDragDelta += screenDelta.dx / (_scale * cw);
        } else {
          _edgeDragDelta += screenDelta.dy / (_scale * ch);
        }
      } else if (_pointers.length >= 2 &&
          _lastPointerDistance != null &&
          _lastPointerDistance! > 0) {
        final d = _getPointerDistance();
        final factor = d / _lastPointerDistance!;
        if (widget.selectedBlockId != null) {
          _zoomSelectedImage(factor);
        } else {
          _scale = (_scale * factor).clamp(0.01, 20.0);
          if (_lastMidpoint != null) _translation += (mid - _lastMidpoint!);
        }
        _lastPointerDistance = d;
      } else if (_pointers.length == 1 && _lastMidpoint != null) {
        if (_isMovingImage) {
          final screenDelta = mid - _lastMidpoint!;
          _moveDeltaX += screenDelta.dx / _scale;
          _moveDeltaY += screenDelta.dy / _scale;
        } else {
          _translation += (mid - _lastMidpoint!);
        }
      }
    });
    _lastMidpoint = mid;
  }

  /// 将本地坐标转为画布坐标
  Offset _localToCanvas(Offset local) {
    return Offset(
      (local.dx - _translation.dx) / _scale,
      (local.dy - _translation.dy) / _scale,
    );
  }

  void _onPointerUp(PointerUpEvent e) {
    final wasMoving = _isMovingImage;
    final movingId = _movingBlockId;
    final wasDraggingEdge = _isDraggingEdge;
    final draggedEdge = _draggingEdge;
    final upLocal = e.localPosition;

    _pointers.remove(e.pointer);
    if (_pointers.isEmpty) {
      _lastMidpoint = null;
      _lastPointerDistance = null;

      if (!_hasMoved) {
        // ━━━ 点击（无移动）━━━ 手动 hit-test，不依赖 Transform
        final canvas = _localToCanvas(upLocal);
        final tappedId = _findBlockAtCanvasPos(canvas.dx, canvas.dy);
        if (tappedId != null) {
          widget.onBlockTap(tappedId);
        } else {
          widget.onCanvasTap();
        }
        _cleanupPointerState();
        return;
      }

      if (wasDraggingEdge && draggedEdge != null) {
        _commitEdgeDrag(draggedEdge, _edgeDragDelta);
        setState(() {
          _isDraggingEdge = false;
          _draggingEdge = null;
          _edgeDragDelta = 0;
        });
      } else if (wasMoving && movingId != null) {
        final idx = widget.imageBlocks.indexWhere((b) => b.id == movingId);
        if (idx >= 0) {
          final block = widget.imageBlocks[idx];
          final cw = widget.canvasConfig.width;
          final ch = widget.canvasConfig.height;
          final abs = block.toAbsolute(cw, ch);

          if (_isDeltaWithinBounds()) {
            final (overflowX, overflowY) = calcCoverOverflow(abs);
            final maxOx =
                overflowX * block.scale + abs.width * (block.scale - 1) / 2;
            final maxOy =
                overflowY * block.scale + abs.height * (block.scale - 1) / 2;
            final newOx = (block.offsetX + _moveDeltaX).clamp(-maxOx, maxOx);
            final newOy = (block.offsetY + _moveDeltaY).clamp(-maxOy, maxOy);
            widget.onBlockChanged(
                movingId, block.copyWith(offsetX: newOx, offsetY: newOy));
          } else {
            final centerX = abs.x + _moveDeltaX + abs.width / 2;
            final centerY = abs.y + _moveDeltaY + abs.height / 2;
            final targetId =
                _findBlockAtCanvasPos(centerX, centerY, excludeId: movingId);
            if (targetId != null) {
              widget.onBlockSwap(movingId, targetId);
            }
          }
        }
        _cleanupPointerState();
      }
    } else {
      _lastMidpoint = _getMidpoint();
      if (_pointers.length >= 2) _lastPointerDistance = _getPointerDistance();
    }
  }

  void _cleanupPointerState() {
    setState(() {
      _moveDeltaX = 0;
      _moveDeltaY = 0;
      _isMovingImage = false;
      _movingBlockId = null;
      _isDraggingEdge = false;
      _draggingEdge = null;
      _edgeDragDelta = 0;
    });
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isEmpty) {
      _lastMidpoint = null;
      _lastPointerDistance = null;
      setState(() {
        _moveDeltaX = 0;
        _moveDeltaY = 0;
        _isMovingImage = false;
        _movingBlockId = null;
        _isDraggingEdge = false;
        _draggingEdge = null;
        _edgeDragDelta = 0;
      });
    }
  }

  void _commitEdgeDrag(SharedEdge edge, double delta) {
    final updated = commitEdgeDrag(widget.imageBlocks, edge, delta);
    if (updated != widget.imageBlocks) {
      widget.onBlocksResized(updated);
    }
  }

  void _zoomSelectedImage(double factor) {
    final idx =
        widget.imageBlocks.indexWhere((b) => b.id == widget.selectedBlockId);
    if (idx < 0) return;
    final block = widget.imageBlocks[idx];
    final newScale = (block.scale * factor).clamp(1.0, 5.0);
    final cw = widget.canvasConfig.width;
    final ch = widget.canvasConfig.height;
    final abs = block.toAbsolute(cw, ch);
    final (overflowX, overflowY) = calcCoverOverflow(abs);
    final maxOx = overflowX * newScale + abs.width * (newScale - 1) / 2;
    final maxOy = overflowY * newScale + abs.height * (newScale - 1) / 2;
    widget.onBlockChanged(
        block.id,
        block.copyWith(
          scale: newScale,
          offsetX: block.offsetX.clamp(-maxOx, maxOx),
          offsetY: block.offsetY.clamp(-maxOy, maxOy),
        ));
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
        if (_needsRecenter &&
            constraints.maxWidth > 0 &&
            constraints.maxHeight > 0) {
          _computeCenter(constraints.maxWidth, constraints.maxHeight);
          _needsRecenter = false;
        }

        return Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          behavior: HitTestBehavior.translucent,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onDoubleTap: _resetView,
                    behavior: HitTestBehavior.opaque,
                    child: Container(color: const Color(0xFFE8E8E8)),
                  ),
                ),
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
                          color: Colors.black,
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
                          children: [
                            // 图片块
                            ...sortedBlocks.map((block) {
                              final selected =
                                  widget.selectedBlockId == block.id;
                              final abs = block.toAbsolute(cw, ch);
                              final isMoving =
                                  _isMovingImage && _movingBlockId == block.id;
                              final blockIdx = widget.imageBlocks
                                  .indexWhere((b) => b.id == block.id);
                              VideoPlayerController? vc;
                              if (widget.isPlaying &&
                                  widget.videoControllers != null) {
                                vc = widget.videoControllers![blockIdx];
                              } else if (blockIdx ==
                                  widget.frameEditingBlockIdx) {
                                vc = widget.frameEditingController;
                              }
                              return CanvasImageBlockWidget(
                                key: ValueKey(block.id),
                                block: block,
                                abs: abs,
                                selected: selected,
                                isMoving: isMoving,
                                withinBounds:
                                    isMoving ? _isDeltaWithinBounds() : true,
                                moveDeltaX: _moveDeltaX,
                                moveDeltaY: _moveDeltaY,
                                videoController: vc,
                              );
                            }),
                            // 共享边拖动条（实时预览）
                            ...buildEdgeDividers(
                              cw: cw,
                              ch: ch,
                              imageBlocks: widget.imageBlocks,
                              selectedBlockId: widget.selectedBlockId,
                              isDraggingEdge: _isDraggingEdge,
                              draggingEdge: _draggingEdge,
                              edgeDragDelta: _edgeDragDelta,
                            ),
                          ],
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
