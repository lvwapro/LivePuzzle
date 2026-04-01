import '../../models/image_block.dart';

/// 共享边信息
class SharedEdge {
  final bool isVertical;
  final double position;
  final List<String> leftOrTopIds;
  final List<String> rightOrBottomIds;

  SharedEdge({
    required this.isVertical,
    required this.position,
    required this.leftOrTopIds,
    required this.rightOrBottomIds,
  });
}

/// 找到选中图片相关的共享边（只返回与 selectedBlockId 相邻的边）
List<SharedEdge> findSelectedEdges(
    List<ImageBlock> blocks, String? selectedId) {
  if (selectedId == null) return [];
  final all = findAllSharedEdges(blocks);
  return all
      .where((e) =>
          e.leftOrTopIds.contains(selectedId) ||
          e.rightOrBottomIds.contains(selectedId))
      .toList();
}

/// 找到所有共享边
List<SharedEdge> findAllSharedEdges(List<ImageBlock> blocks) {
  if (blocks.length < 2) return [];
  final edges = <SharedEdge>[];
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
      if ((fv - rightX).abs() < tolerance) {
        alreadyFound = true;
        break;
      }
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
      edges.add(SharedEdge(
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
      if ((fh - bottomY).abs() < tolerance) {
        alreadyFound = true;
        break;
      }
    }
    if (alreadyFound) continue;

    final topIds = <String>[];
    final bottomIds = <String>[];
    for (int j = 0; j < blocks.length; j++) {
      if ((allBottoms[j] - bottomY).abs() < tolerance) topIds.add(blocks[j].id);
      if ((allTops[j] - bottomY).abs() < tolerance) {
        bottomIds.add(blocks[j].id);
      }
    }
    if (topIds.isNotEmpty && bottomIds.isNotEmpty) {
      foundHEdges.add(bottomY);
      edges.add(SharedEdge(
        isVertical: false,
        position: bottomY,
        leftOrTopIds: topIds,
        rightOrBottomIds: bottomIds,
      ));
    }
  }

  return edges;
}

/// 提交边缘拖动：调整相邻blocks的尺寸，返回更新后的列表
List<ImageBlock> commitEdgeDrag(
    List<ImageBlock> blocks, SharedEdge edge, double delta) {
  if (delta.abs() < 0.005) return blocks;

  const minSize = 0.1;
  final result = List<ImageBlock>.from(blocks);

  final newPos = (edge.position + delta).clamp(minSize, 1.0 - minSize);
  final actualDelta = newPos - edge.position;
  if (actualDelta.abs() < 0.005) return blocks;

  for (int i = 0; i < result.length; i++) {
    final b = result[i];
    if (edge.isVertical) {
      if (edge.leftOrTopIds.contains(b.id)) {
        final newW = (b.width + actualDelta).clamp(minSize, 1.0);
        result[i] = b.copyWith(width: newW, offsetX: 0, offsetY: 0);
      } else if (edge.rightOrBottomIds.contains(b.id)) {
        final newX = (b.x + actualDelta).clamp(0.0, 1.0 - minSize);
        final newW = (b.width - actualDelta).clamp(minSize, 1.0);
        result[i] = b.copyWith(x: newX, width: newW, offsetX: 0, offsetY: 0);
      }
    } else {
      if (edge.leftOrTopIds.contains(b.id)) {
        final newH = (b.height + actualDelta).clamp(minSize, 1.0);
        result[i] = b.copyWith(height: newH, offsetX: 0, offsetY: 0);
      } else if (edge.rightOrBottomIds.contains(b.id)) {
        final newY = (b.y + actualDelta).clamp(0.0, 1.0 - minSize);
        final newH = (b.height - actualDelta).clamp(minSize, 1.0);
        result[i] = b.copyWith(y: newY, height: newH, offsetX: 0, offsetY: 0);
      }
    }
  }

  return result;
}
