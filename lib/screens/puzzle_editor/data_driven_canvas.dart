import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/canvas_config.dart';
import '../../models/image_block.dart';

/// 共享边信息
class _SharedEdge {
  final bool isVertical; // true=竖线(左右分界), false=横线(上下分界)
  final double position; // 相对位置(0-1)
  final List<String> leftOrTopIds; // 边左侧/上方的block IDs
  final List<String> rightOrBottomIds; // 边右侧/下方的block IDs

  _SharedEdge({
    required this.isVertical,
    required this.position,
    required this.leftOrTopIds,
    required this.rightOrBottomIds,
  });
}

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
  _SharedEdge? _draggingEdge;
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
    final s = math.min(vw / cw, vh / ch) * 0.9;
    _scale = s;
    _translation = Offset((vw - cw * s) / 2, (vh - ch * s) / 2);
  }

  void _resetView() {
    if (!mounted) return;
    final rb = context.findRenderObject() as RenderBox?;
    if (rb == null || !rb.hasSize) return;
    setState(() => _computeCenter(rb.size.width, rb.size.height));
  }

  // ━━━ 共享边检测 ━━━

  /// 找到选中图片相关的共享边（只返回与 selectedBlockId 相邻的边）
  List<_SharedEdge> _findSelectedEdges() {
    final selectedId = widget.selectedBlockId;
    if (selectedId == null) return [];
    final all = _findAllSharedEdges();
    return all.where((e) =>
        e.leftOrTopIds.contains(selectedId) ||
        e.rightOrBottomIds.contains(selectedId)).toList();
  }

  /// 找到所有共享边
  List<_SharedEdge> _findAllSharedEdges() {
    final blocks = widget.imageBlocks;
    if (blocks.length < 2) return [];
    final edges = <_SharedEdge>[];
    const tolerance = 0.015;

    final allRights = <double>[];
    final allBottoms = <double>[];
    final allLefts = <double>[];
    final allTops = <double>[];

    for (final b in blocks) {
      allRights.add(b.x + b.width);
      allBottoms.add(b.y + b.height);
      allLefts.add(b.x);
      allTops.add(b.y);
    }

    // 垂直共享边
    final foundVEdges = <double>[];
    for (int i = 0; i < blocks.length; i++) {
      final rightX = allRights[i];
      if (rightX < tolerance || rightX > 1.0 - tolerance) continue;
      bool alreadyFound = false;
      for (final fv in foundVEdges) {
        if ((fv - rightX).abs() < tolerance) { alreadyFound = true; break; }
      }
      if (alreadyFound) continue;

      final leftIds = <String>[];
      final rightIds = <String>[];
      for (int j = 0; j < blocks.length; j++) {
        if ((allRights[j] - rightX).abs() < tolerance) leftIds.add(blocks[j].id);
        if ((allLefts[j] - rightX).abs() < tolerance) rightIds.add(blocks[j].id);
      }
      if (leftIds.isNotEmpty && rightIds.isNotEmpty) {
        foundVEdges.add(rightX);
        edges.add(_SharedEdge(
          isVertical: true,
          position: rightX,
          leftOrTopIds: leftIds,
          rightOrBottomIds: rightIds,
        ));
      }
    }

    // 水平共享边
    final foundHEdges = <double>[];
    for (int i = 0; i < blocks.length; i++) {
      final bottomY = allBottoms[i];
      if (bottomY < tolerance || bottomY > 1.0 - tolerance) continue;
      bool alreadyFound = false;
      for (final fh in foundHEdges) {
        if ((fh - bottomY).abs() < tolerance) { alreadyFound = true; break; }
      }
      if (alreadyFound) continue;

      final topIds = <String>[];
      final bottomIds = <String>[];
      for (int j = 0; j < blocks.length; j++) {
        if ((allBottoms[j] - bottomY).abs() < tolerance) topIds.add(blocks[j].id);
        if ((allTops[j] - bottomY).abs() < tolerance) bottomIds.add(blocks[j].id);
      }
      if (topIds.isNotEmpty && bottomIds.isNotEmpty) {
        foundHEdges.add(bottomY);
        edges.add(_SharedEdge(
          isVertical: false,
          position: bottomY,
          leftOrTopIds: topIds,
          rightOrBottomIds: bottomIds,
        ));
      }
    }

    return edges;
  }

  /// 检查屏幕坐标是否靠近选中图片的某条共享边，返回匹配的边
  _SharedEdge? _findEdgeAtScreenPos(Offset screenPos) {
    // 只有选中图片时才能拖动边
    if (widget.selectedBlockId == null) return null;

    final cw = widget.canvasConfig.width;
    final ch = widget.canvasConfig.height;
    final canvasX = (screenPos.dx - _translation.dx) / _scale;
    final canvasY = (screenPos.dy - _translation.dy) / _scale;
    final relX = canvasX / cw;
    final relY = canvasY / ch;

    // 20屏幕像素 → 相对坐标
    final hitDistX = 20.0 / (_scale * cw);
    final hitDistY = 20.0 / (_scale * ch);

    final edges = _findSelectedEdges();
    for (final edge in edges) {
      if (edge.isVertical) {
        if ((relX - edge.position).abs() < hitDistX && relY > -0.02 && relY < 1.02) {
          return edge;
        }
      } else {
        if ((relY - edge.position).abs() < hitDistY && relX > -0.02 && relX < 1.02) {
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
      if (cx >= abs.x && cx <= abs.x + abs.width &&
          cy >= abs.y && cy <= abs.y + abs.height) {
        return block.id;
      }
    }
    return null;
  }

  // ---- 指针事件 ----

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

    // 检查是否点在共享边上
    if (_pointers.length == 1) {
      final edge = _findEdgeAtScreenPos(e.position);
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
    _pointers[e.pointer] = e.position;
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
      } else if (_pointers.length >= 2 && _lastPointerDistance != null && _lastPointerDistance! > 0) {
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

  void _onPointerUp(PointerUpEvent e) {
    final wasMoving = _isMovingImage;
    final movingId = _movingBlockId;
    final wasDraggingEdge = _isDraggingEdge;
    final draggedEdge = _draggingEdge;

    _pointers.remove(e.pointer);
    if (_pointers.isEmpty) {
      _lastMidpoint = null;
      _lastPointerDistance = null;

      if (wasDraggingEdge && draggedEdge != null) {
        // ━━━ 提交边缘拖动 ━━━
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
            final (overflowX, overflowY) = _calcCoverOverflow(abs);
            final maxOx = overflowX * block.scale + abs.width * (block.scale - 1) / 2;
            final maxOy = overflowY * block.scale + abs.height * (block.scale - 1) / 2;
            final newOx = (block.offsetX + _moveDeltaX).clamp(-maxOx, maxOx);
            final newOy = (block.offsetY + _moveDeltaY).clamp(-maxOy, maxOy);
            widget.onBlockChanged(movingId, block.copyWith(offsetX: newOx, offsetY: newOy));
          } else {
            final centerX = abs.x + _moveDeltaX + abs.width / 2;
            final centerY = abs.y + _moveDeltaY + abs.height / 2;
            final targetId = _findBlockAtCanvasPos(centerX, centerY, excludeId: movingId);
            if (targetId != null) {
              widget.onBlockSwap(movingId, targetId);
            }
          }
        }
        setState(() {
          _moveDeltaX = 0;
          _moveDeltaY = 0;
          _isMovingImage = false;
          _movingBlockId = null;
        });
      }
    } else {
      _lastMidpoint = _getMidpoint();
      if (_pointers.length >= 2) _lastPointerDistance = _getPointerDistance();
    }
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

  /// 提交边缘拖动：调整相邻blocks的尺寸
  void _commitEdgeDrag(_SharedEdge edge, double delta) {
    if (delta.abs() < 0.005) return; // 忽略微小移动

    const minSize = 0.1; // 最小占比 10%
    final blocks = List<ImageBlock>.from(widget.imageBlocks);

    // 检查边界
    final newPos = (edge.position + delta).clamp(minSize, 1.0 - minSize);
    final actualDelta = newPos - edge.position;
    if (actualDelta.abs() < 0.005) return;

    for (int i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (edge.isVertical) {
        // 垂直边：调整左侧 width，右侧 x + width
        if (edge.leftOrTopIds.contains(b.id)) {
          final newW = (b.width + actualDelta).clamp(minSize, 1.0);
          blocks[i] = b.copyWith(width: newW, offsetX: 0, offsetY: 0);
        } else if (edge.rightOrBottomIds.contains(b.id)) {
          final newX = (b.x + actualDelta).clamp(0.0, 1.0 - minSize);
          final newW = (b.width - actualDelta).clamp(minSize, 1.0);
          blocks[i] = b.copyWith(x: newX, width: newW, offsetX: 0, offsetY: 0);
        }
      } else {
        // 水平边：调整上方 height，下方 y + height
        if (edge.leftOrTopIds.contains(b.id)) {
          final newH = (b.height + actualDelta).clamp(minSize, 1.0);
          blocks[i] = b.copyWith(height: newH, offsetX: 0, offsetY: 0);
        } else if (edge.rightOrBottomIds.contains(b.id)) {
          final newY = (b.y + actualDelta).clamp(0.0, 1.0 - minSize);
          final newH = (b.height - actualDelta).clamp(minSize, 1.0);
          blocks[i] = b.copyWith(y: newY, height: newH, offsetX: 0, offsetY: 0);
        }
      }
    }

    widget.onBlocksResized(blocks);
  }

  void _zoomSelectedImage(double factor) {
    final idx = widget.imageBlocks.indexWhere((b) => b.id == widget.selectedBlockId);
    if (idx < 0) return;
    final block = widget.imageBlocks[idx];
    final newScale = (block.scale * factor).clamp(1.0, 5.0);
    final cw = widget.canvasConfig.width;
    final ch = widget.canvasConfig.height;
    final abs = block.toAbsolute(cw, ch);
    final (overflowX, overflowY) = _calcCoverOverflow(abs);
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
        if (_needsRecenter && constraints.maxWidth > 0 && constraints.maxHeight > 0) {
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
                    onTap: () { if (!_hasMoved) widget.onCanvasTap(); },
                    onDoubleTap: _resetView,
                    behavior: HitTestBehavior.opaque,
                    child: Container(color: const Color(0xFFF5F5F5)),
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
                          children: [
                            // 图片块
                            ...sortedBlocks.map((block) {
                              final selected = widget.selectedBlockId == block.id;
                              final abs = block.toAbsolute(cw, ch);
                              final isMoving = _isMovingImage && _movingBlockId == block.id;
                              return _buildImageBlock(block, abs, selected, isMoving);
                            }),
                            // 共享边拖动条（实时预览）
                            ..._buildEdgeDividers(cw, ch),
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

  /// 构建选中图片的共享边可视拖动条
  List<Widget> _buildEdgeDividers(double cw, double ch) {
    // 只有选中图片时才显示
    if (widget.selectedBlockId == null && !_isDraggingEdge) return [];
    final edges = _isDraggingEdge && _draggingEdge != null
        ? [_draggingEdge!]  // 拖动中只显示正在拖的边
        : _findSelectedEdges();
    final dividers = <Widget>[];
    // 尺寸按画布比例计算，确保缩放后在屏幕上可见
    final handleThick = math.max(cw, ch) * 0.012;  // 手柄粗度
    final handleLen = math.min(cw, ch) * 0.08;      // 手柄长度
    final lineThick = math.max(cw, ch) * 0.004;     // 分界线粗度
    final hitArea = math.max(cw, ch) * 0.03;        // 触控区域

    for (final edge in edges) {
      double pos = edge.position;
      final isDragging = _isDraggingEdge && _draggingEdge != null &&
          _draggingEdge!.position == edge.position &&
          _draggingEdge!.isVertical == edge.isVertical;
      if (isDragging) {
        pos = (pos + _edgeDragDelta).clamp(0.1, 0.9);
      }

      if (edge.isVertical) {
        final x = pos * cw;
        // 整条分界线
        dividers.add(Positioned(
          left: x - lineThick / 2,
          top: 0,
          width: lineThick,
          height: ch,
          child: Container(
            color: isDragging
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.4),
          ),
        ));
        // 中间拖动手柄
        dividers.add(Positioned(
          left: x - hitArea / 2,
          top: (ch - handleLen) / 2,
          width: hitArea,
          height: handleLen,
          child: Center(
            child: Container(
              width: handleThick,
              height: handleLen,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(handleThick / 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: handleThick,
                    spreadRadius: lineThick,
                  ),
                ],
              ),
            ),
          ),
        ));
      } else {
        final y = pos * ch;
        // 整条分界线
        dividers.add(Positioned(
          left: 0,
          top: y - lineThick / 2,
          width: cw,
          height: lineThick,
          child: Container(
            color: isDragging
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.4),
          ),
        ));
        // 中间拖动手柄
        dividers.add(Positioned(
          left: (cw - handleLen) / 2,
          top: y - hitArea / 2,
          width: handleLen,
          height: hitArea,
          child: Center(
            child: Container(
              width: handleLen,
              height: handleThick,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(handleThick / 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: handleThick,
                    spreadRadius: lineThick,
                  ),
                ],
              ),
            ),
          ),
        ));
      }
    }

    return dividers;
  }

  (double, double) _calcCoverOverflow(ImageBlockAbsolute abs) {
    final imgAR = abs.imageAspectRatio;
    if (imgAR <= 0) return (0, 0);
    final frameAR = abs.width / abs.height;
    if (imgAR > frameAR) {
      final coverW = abs.height * imgAR;
      return ((coverW - abs.width) / 2, 0);
    } else {
      final coverH = abs.width / imgAR;
      return (0, (coverH - abs.height) / 2);
    }
  }

  Widget _buildImageBlock(
    ImageBlock block, ImageBlockAbsolute abs, bool selected, bool isMoving,
  ) {
    final withinBounds = isMoving ? _isDeltaWithinBounds() : true;

    final (overflowX, overflowY) = _calcCoverOverflow(abs);
    final maxOx = overflowX * block.scale + abs.width * (block.scale - 1) / 2;
    final maxOy = overflowY * block.scale + abs.height * (block.scale - 1) / 2;

    double previewOx = block.offsetX;
    double previewOy = block.offsetY;
    if (isMoving && withinBounds) {
      previewOx = (block.offsetX + _moveDeltaX).clamp(-maxOx, maxOx);
      previewOy = (block.offsetY + _moveDeltaY).clamp(-maxOy, maxOy);
    }

    Widget imageContent;
    if (abs.imageData != null && abs.imageAspectRatio > 0) {
      final frameAR = abs.width / abs.height;
      final imgAR = abs.imageAspectRatio;
      double coverW, coverH;
      if (imgAR > frameAR) {
        coverH = abs.height;
        coverW = abs.height * imgAR;
      } else {
        coverW = abs.width;
        coverH = abs.width / imgAR;
      }
      coverW *= block.scale;
      coverH *= block.scale;

      final left = (abs.width - coverW) / 2 + previewOx;
      final top = (abs.height - coverH) / 2 + previewOy;

      imageContent = SizedBox(
        width: abs.width,
        height: abs.height,
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: left,
                top: top,
                width: coverW,
                height: coverH,
                child: Image.memory(
                  abs.imageData!,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      imageContent = SizedBox(
        width: abs.width,
        height: abs.height,
        child: abs.imageData != null
            ? Image.memory(
                abs.imageData!,
                fit: BoxFit.cover,
                width: abs.width,
                height: abs.height,
                gaplessPlayback: true,
                filterQuality: FilterQuality.high,
              )
            : const Center(child: Icon(Icons.image, color: Colors.grey)),
      );
    }

    BoxDecoration? deco;
    if (isMoving && !withinBounds) {
      deco = BoxDecoration(
        border: Border.all(color: const Color(0xFF4FC3F7), width: 4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4FC3F7).withValues(alpha: 0.5),
            blurRadius: 16,
            spreadRadius: 4,
          ),
        ],
      );
    } else if (selected) {
      deco = BoxDecoration(
        border: Border.all(color: const Color(0xFFFF85A2), width: 5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF85A2).withValues(alpha: 0.4),
            blurRadius: 14,
            spreadRadius: 3,
          ),
        ],
      );
    }

    Widget content = Container(
      width: abs.width,
      height: abs.height,
      decoration: deco,
      child: imageContent,
    );

    final posX = abs.x + (isMoving && !withinBounds ? _moveDeltaX : 0);
    final posY = abs.y + (isMoving && !withinBounds ? _moveDeltaY : 0);

    return Positioned(
      left: posX,
      top: posY,
      child: GestureDetector(
        onTap: () {
          if (!_hasMoved && !_isMovingImage) {
            widget.onBlockTap(block.id);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: isMoving && !withinBounds ? 0.8 : 1.0,
          child: content,
        ),
      ),
    );
  }
}
