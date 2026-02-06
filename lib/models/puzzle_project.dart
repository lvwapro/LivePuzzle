import 'package:live_puzzle/models/frame_data.dart';
import 'package:live_puzzle/models/puzzle_layout.dart';

/// 拼图项目模型
class PuzzleProject {
  final String id;
  final String name;
  final PuzzleLayout layout;
  final List<SelectedFrame> frames;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? outputPath;

  const PuzzleProject({
    required this.id,
    required this.name,
    required this.layout,
    required this.frames,
    required this.createdAt,
    required this.updatedAt,
    this.outputPath,
  });

  PuzzleProject copyWith({
    String? id,
    String? name,
    PuzzleLayout? layout,
    List<SelectedFrame>? frames,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? outputPath,
  }) {
    return PuzzleProject(
      id: id ?? this.id,
      name: name ?? this.name,
      layout: layout ?? this.layout,
      frames: frames ?? this.frames,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      outputPath: outputPath ?? this.outputPath,
    );
  }

  bool get isComplete => frames.length == layout.cells.length;
  
  int get completionPercentage => 
      ((frames.length / layout.cells.length) * 100).round();
}
