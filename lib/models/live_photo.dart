import 'dart:io';

/// Live Photo数据模型
class LivePhoto {
  final String id;
  final String imagePath;
  final String videoPath;
  final Duration duration;
  final DateTime createdAt;
  final int frameCount;
  final File? imageFile;
  final File? videoFile;

  const LivePhoto({
    required this.id,
    required this.imagePath,
    required this.videoPath,
    required this.duration,
    required this.createdAt,
    required this.frameCount,
    this.imageFile,
    this.videoFile,
  });

  LivePhoto copyWith({
    String? id,
    String? imagePath,
    String? videoPath,
    Duration? duration,
    DateTime? createdAt,
    int? frameCount,
    File? imageFile,
    File? videoFile,
  }) {
    return LivePhoto(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      videoPath: videoPath ?? this.videoPath,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      frameCount: frameCount ?? this.frameCount,
      imageFile: imageFile ?? this.imageFile,
      videoFile: videoFile ?? this.videoFile,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'videoPath': videoPath,
      'duration': duration.inMilliseconds,
      'createdAt': createdAt.toIso8601String(),
      'frameCount': frameCount,
    };
  }

  factory LivePhoto.fromJson(Map<String, dynamic> json) {
    return LivePhoto(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      videoPath: json['videoPath'] as String,
      duration: Duration(milliseconds: json['duration'] as int),
      createdAt: DateTime.parse(json['createdAt'] as String),
      frameCount: json['frameCount'] as int,
    );
  }
}
