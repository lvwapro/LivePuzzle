import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_puzzle/models/puzzle_project.dart';
import 'package:live_puzzle/models/puzzle_layout.dart';
import 'package:live_puzzle/models/frame_data.dart';
import 'package:uuid/uuid.dart';

/// 当前拼图项目状态
final puzzleProjectProvider =
    StateNotifierProvider<PuzzleProjectNotifier, PuzzleProject?>(
  (ref) => PuzzleProjectNotifier(),
);

class PuzzleProjectNotifier extends StateNotifier<PuzzleProject?> {
  PuzzleProjectNotifier() : super(null);

  void createProject(PuzzleLayout layout) {
    final now = DateTime.now();
    state = PuzzleProject(
      id: const Uuid().v4(),
      name: 'Puzzle ${now.toString().substring(0, 19)}',
      layout: layout,
      frames: [],
      createdAt: now,
      updatedAt: now,
    );
  }

  void updateLayout(PuzzleLayout layout) {
    if (state == null) return;
    state = state!.copyWith(
      layout: layout,
      updatedAt: DateTime.now(),
    );
  }

  void addFrame(SelectedFrame frame) {
    if (state == null) return;
    state = state!.copyWith(
      frames: [...state!.frames, frame],
      updatedAt: DateTime.now(),
    );
  }

  void removeFrame(int index) {
    if (state == null) return;
    final frames = List<SelectedFrame>.from(state!.frames);
    frames.removeAt(index);
    state = state!.copyWith(
      frames: frames,
      updatedAt: DateTime.now(),
    );
  }

  void updateFrame(int index, SelectedFrame frame) {
    if (state == null) return;
    final frames = List<SelectedFrame>.from(state!.frames);
    frames[index] = frame;
    state = state!.copyWith(
      frames: frames,
      updatedAt: DateTime.now(),
    );
  }

  void clear() {
    state = null;
  }

  void setOutputPath(String path) {
    if (state == null) return;
    state = state!.copyWith(
      outputPath: path,
      updatedAt: DateTime.now(),
    );
  }
}

/// 选中的布局类型
final selectedLayoutTypeProvider =
    StateProvider<LayoutType>((ref) => LayoutType.grid2x2);

/// 拼图编辑状态
final puzzleEditingStateProvider =
    StateNotifierProvider<PuzzleEditingStateNotifier, PuzzleEditingState>(
  (ref) => PuzzleEditingStateNotifier(),
);

class PuzzleEditingState {
  final int? selectedCellIndex;
  final bool isEditing;
  final double zoom;
  final Offset offset;

  const PuzzleEditingState({
    this.selectedCellIndex,
    this.isEditing = false,
    this.zoom = 1.0,
    this.offset = Offset.zero,
  });

  PuzzleEditingState copyWith({
    int? selectedCellIndex,
    bool? isEditing,
    double? zoom,
    Offset? offset,
  }) {
    return PuzzleEditingState(
      selectedCellIndex: selectedCellIndex ?? this.selectedCellIndex,
      isEditing: isEditing ?? this.isEditing,
      zoom: zoom ?? this.zoom,
      offset: offset ?? this.offset,
    );
  }
}

class PuzzleEditingStateNotifier extends StateNotifier<PuzzleEditingState> {
  PuzzleEditingStateNotifier() : super(const PuzzleEditingState());

  void selectCell(int? index) {
    state = state.copyWith(selectedCellIndex: index);
  }

  void setEditing(bool isEditing) {
    state = state.copyWith(isEditing: isEditing);
  }

  void setZoom(double zoom) {
    state = state.copyWith(zoom: zoom);
  }

  void setOffset(Offset offset) {
    state = state.copyWith(offset: offset);
  }

  void reset() {
    state = const PuzzleEditingState();
  }
}
