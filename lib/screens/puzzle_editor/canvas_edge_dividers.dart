import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/image_block.dart';
import 'canvas_shared_edge.dart';

/// 构建选中图片的共享边可视拖动条
List<Widget> buildEdgeDividers({
  required double cw,
  required double ch,
  required List<ImageBlock> imageBlocks,
  required String? selectedBlockId,
  required bool isDraggingEdge,
  required SharedEdge? draggingEdge,
  required double edgeDragDelta,
}) {
  if (selectedBlockId == null && !isDraggingEdge) return [];
  final edges = isDraggingEdge && draggingEdge != null
      ? [draggingEdge]
      : findSelectedEdges(imageBlocks, selectedBlockId);
  final dividers = <Widget>[];
  final handleThick = math.max(cw, ch) * 0.012;
  final handleLen = math.min(cw, ch) * 0.08;
  final lineThick = math.max(cw, ch) * 0.004;
  final hitArea = math.max(cw, ch) * 0.03;

  for (final edge in edges) {
    double pos = edge.position;
    final dragging = isDraggingEdge &&
        draggingEdge != null &&
        draggingEdge.position == edge.position &&
        draggingEdge.isVertical == edge.isVertical;
    if (dragging) {
      pos = (pos + edgeDragDelta).clamp(0.1, 0.9);
    }

    if (edge.isVertical) {
      final x = pos * cw;
      dividers.add(Positioned(
        left: x - lineThick / 2,
        top: 0,
        width: lineThick,
        height: ch,
        child: Container(
          color: dragging
              ? Colors.white.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.4),
        ),
      ));
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
      dividers.add(Positioned(
        left: 0,
        top: y - lineThick / 2,
        width: cw,
        height: lineThick,
        child: Container(
          color: dragging
              ? Colors.white.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.4),
        ),
      ));
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
