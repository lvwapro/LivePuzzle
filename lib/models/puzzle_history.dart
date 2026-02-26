import 'dart:typed_data';

/// 拼图历史记录
class PuzzleHistory {
  final String id; // 唯一标识
  final List<String> photoIds; // 照片ID列表
  final DateTime createdAt; // 创建时间
  final Uint8List? thumbnail; // 缩略图
  final int photoCount; // 照片数量

  const PuzzleHistory({
    required this.id,
    required this.photoIds,
    required this.createdAt,
    this.thumbnail,
    required this.photoCount,
  });

  /// 从JSON创建
  factory PuzzleHistory.fromJson(Map<String, dynamic> json) {
    return PuzzleHistory(
      id: json['id'] as String,
      photoIds: (json['photoIds'] as List).cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      thumbnail: json['thumbnail'] != null 
          ? Uint8List.fromList((json['thumbnail'] as List).cast<int>()) 
          : null,
      photoCount: json['photoCount'] as int,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'photoIds': photoIds,
      'createdAt': createdAt.toIso8601String(),
      'thumbnail': thumbnail?.toList(),
      'photoCount': photoCount,
    };
  }

  /// 获取时间差描述
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'JUST NOW';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} MIN AGO';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} HOUR${difference.inHours > 1 ? 'S' : ''} AGO';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} DAY${difference.inDays > 1 ? 'S' : ''} AGO';
    } else {
      return '${difference.inDays ~/ 7} WEEK${difference.inDays ~/ 7 > 1 ? 'S' : ''} AGO';
    }
  }
}
