import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/canvas_config.dart';
import '../../models/image_block.dart';

/// 数据驱动画布组件
/// 手势：
///   未选中：单指=画布平移，双指=画布缩放，双击=重置
///   选中图片：
///     - 在自身范围内拖动 = 移动图片内容（裁切平移），无蒙层
///     - 拖出自身范围 = 位置互换模式（拖到另一张图上松手互换）
///     - 双指 = 缩放图片
class DataDrivenCanvas extends StatefulWidget {
  final CanvasConfig canvasConfig;
  final List<ImageBlock> imageBlocks;
  final String? selectedBlockId;
  final Function(String blockId) onBlockTap;
  final Function(String blockId, ImageBlock updatedBlock) onBlockChanged;
  final Function(String sourceId, String targetId) onBlockSwap;
  final VoidCallback onCanvasTap;

  const DataDrivenCanvas({
    super.key,
    required this.canvasConfig,
    required this.imageBlocks,
    this.selectedBlockId,
    required this.onBlockTap,
    required this.onBlockChanged,
    required this.onBlockSwap,
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

  /// 判断当前拖动偏移是否还在选中图片自身范围内
  bool _isDeltaWithinBounds() {
    if (_movingBlockId == null) return true;
    final idx = widget.imageBlocks.indexWhere((b) => b.id == _movingBlockId);
    if (idx < 0) return true;
    final block = widget.imageBlocks[idx];
    final cw = widget.canvasConfig.width;
    final ch = widget.canvasConfig.height;
    final abs = block.toAbsolute(cw, ch);
    // 中心偏移超过自身一半 → 出界
    return _moveDeltaX.abs() <= abs.width * 0.4 &&
        _moveDeltaY.abs() <= abs.height * 0.4;
  }

  /// 找到画布坐标下的图片块
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
    _pointers[e.pointer] = e.position;
    _lastMidpoint = _getMidpoint();
    if (_pointers.length >= 2) _lastPointerDistance = _getPointerDistance();
    _hasMoved = false;

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
        if (_movingBlockId != null && _pointers.length == 1) {
          _isMovingImage = true;
        }
      }
    }
    if (!_hasMoved) return;

    setState(() {
      if (_pointers.length >= 2 &&
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

  void _onPointerUp(PointerUpEvent e) {
    final wasMoving = _isMovingImage;
    final movingId = _movingBlockId;

    _pointers.remove(e.pointer);
    if (_pointers.isEmpty) {
      _lastMidpoint = null;
      _lastPointerDistance = null;

      if (wasMoving && movingId != null) {
        final idx = widget.imageBlocks.indexWhere((b) => b.id == movingId);
        if (idx >= 0) {
          final block = widget.imageBlocks[idx];
          final cw = widget.canvasConfig.width;
          final ch = widget.canvasConfig.height;
          final abs = block.toAbsolute(cw, ch);

          if (_isDeltaWithinBounds()) {
            // ━━━ 在自身范围内 → 调整图片内容偏移（裁切平移）━━━
            final (overflowX, overflowY) = _calcCoverOverflow(abs);
            final maxOx = overflowX * block.scale + abs.width * (block.scale - 1) / 2;
            final maxOy = overflowY * block.scale + abs.height * (block.scale - 1) / 2;
            final newOx = (block.offsetX + _moveDeltaX).clamp(-maxOx, maxOx);
            final newOy = (block.offsetY + _moveDeltaY).clamp(-maxOy, maxOy);
            widget.onBlockChanged(
                movingId,
                block.copyWith(
                  offsetX: newOx,
                  offsetY: newOy,
                ));
          } else {
            // ━━━ 超出自身范围 → 位置互换 ━━━
            final centerX = abs.x + _moveDeltaX + abs.width / 2;
            final centerY = abs.y + _moveDeltaY + abs.height / 2;
            final targetId =
                _findBlockAtCanvasPos(centerX, centerY, excludeId: movingId);
            if (targetId != null) {
              widget.onBlockSwap(movingId, targetId);
            }
            // 没有目标则回弹（不做任何位置变更）
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
      });
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
                    onTap: () {
                      if (!_hasMoved) widget.onCanvasTap();
                    },
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
                          children: sortedBlocks.map((block) {
                            final selected = widget.selectedBlockId == block.id;
                            final abs = block.toAbsolute(cw, ch);
                            final isMoving =
                                _isMovingImage && _movingBlockId == block.id;
                            return _buildImageBlock(
                                block, abs, selected, isMoving);
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

  /// 计算 BoxFit.cover 后图片的溢出量（用于偏移上限）
  /// 返回 (overflowX, overflowY)：图片比框大出多少像素（单侧）
  (double, double) _calcCoverOverflow(ImageBlockAbsolute abs) {
    final imgAR = abs.imageAspectRatio;
    if (imgAR <= 0) return (0, 0);
    final frameAR = abs.width / abs.height;
    if (imgAR > frameAR) {
      // 图片更宽 → 宽度溢出
      final coverW = abs.height * imgAR; // cover后图片宽度
      return ((coverW - abs.width) / 2, 0);
    } else {
      // 图片更高 → 高度溢出
      final coverH = abs.width / imgAR;
      return (0, (coverH - abs.height) / 2);
    }
  }

  Widget _buildImageBlock(
    ImageBlock block,
    ImageBlockAbsolute abs,
    bool selected,
    bool isMoving,
  ) {
    final withinBounds = isMoving ? _isDeltaWithinBounds() : true;

    // 计算 cover 溢出 + 用户缩放后的最大偏移
    final (overflowX, overflowY) = _calcCoverOverflow(abs);
    final maxOx = overflowX * block.scale + abs.width * (block.scale - 1) / 2;
    final maxOy = overflowY * block.scale + abs.height * (block.scale - 1) / 2;

    double previewOx = block.offsetX;
    double previewOy = block.offsetY;
    if (isMoving && withinBounds) {
      previewOx = (block.offsetX + _moveDeltaX).clamp(-maxOx, maxOx);
      previewOy = (block.offsetY + _moveDeltaY).clamp(-maxOy, maxOy);
    }

    // 手动实现 BoxFit.cover + 平移：
    // 将图片放大到恰好覆盖框，然后用 translate 偏移
    Widget imageContent;
    if (abs.imageData != null && abs.imageAspectRatio > 0) {
      final frameAR = abs.width / abs.height;
      final imgAR = abs.imageAspectRatio;
      // cover 尺寸（未额外缩放前）
      double coverW, coverH;
      if (imgAR > frameAR) {
        coverH = abs.height;
        coverW = abs.height * imgAR;
      } else {
        coverW = abs.width;
        coverH = abs.width / imgAR;
      }
      // 加上用户缩放
      coverW *= block.scale;
      coverH *= block.scale;

      imageContent = SizedBox(
        width: abs.width,
        height: abs.height,
        child: ClipRect(
          child: OverflowBox(
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: Transform.translate(
              offset: Offset(previewOx, previewOy),
              child: SizedBox(
                width: coverW,
                height: coverH,
                child: Image.memory(
                  abs.imageData!,
                  fit: BoxFit.fill, // 已计算好尺寸，直接填充
                  width: coverW,
                  height: coverH,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      // 没有宽高比信息或没有图片 → 回退旧逻辑
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

    // 边框样式
    BoxDecoration? deco;
    if (isMoving && !withinBounds) {
      // 超出范围 → 互换模式：蓝色边框
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
      // 选中（含范围内拖动）：粉色边框，无蒙层
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

    // 位置：范围内不移动位置，超出范围才视觉跟手
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
