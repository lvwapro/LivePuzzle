import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:live_puzzle/l10n/app_localizations.dart';

/// 拼图历史记录
class PuzzleHistory {
  final String id; // 唯一标识
  final List<String> photoIds; // 照片ID列表
  final DateTime createdAt; // 创建时间
  final Uint8List? thumbnail; // 缩略图
  final int photoCount; // 照片数量
  /// 上次使用的布局模板 id（如 grid_2x1）
  final String? lastLayoutId;
  /// 上次使用的画布比例（如 3:4）
  final String? lastRatio;
  /// 每个格子的封面帧时间（毫秒），-1 表示使用默认
  final List<int>? lastCoverFrameTimeMs;
  /// 每个区块的变换状态 [{layoutBlockId, offsetX, offsetY, scale}, ...]
  final List<Map<String, dynamic>>? lastBlockTransforms;
  /// 样式：间距（相对值）
  final double? lastSpacing;
  /// 样式：圆角（画布像素）
  final double? lastCornerRadius;
  /// 样式：背景色 ARGB 整数
  final int? lastBackgroundColor;

  const PuzzleHistory({
    required this.id,
    required this.photoIds,
    required this.createdAt,
    this.thumbnail,
    required this.photoCount,
    this.lastLayoutId,
    this.lastRatio,
    this.lastCoverFrameTimeMs,
    this.lastBlockTransforms,
    this.lastSpacing,
    this.lastCornerRadius,
    this.lastBackgroundColor,
  });

  /// 从JSON创建
  factory PuzzleHistory.fromJson(Map<String, dynamic> json) {
    List<int>? coverMs;
    if (json['lastCoverFrameTimeMs'] != null) {
      coverMs = (json['lastCoverFrameTimeMs'] as List).cast<int>();
    }
    List<Map<String, dynamic>>? blockTransforms;
    if (json['lastBlockTransforms'] != null) {
      blockTransforms = (json['lastBlockTransforms'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return PuzzleHistory(
      id: json['id'] as String,
      photoIds: (json['photoIds'] as List).cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      thumbnail: json['thumbnail'] != null
          ? Uint8List.fromList((json['thumbnail'] as List).cast<int>())
          : null,
      photoCount: json['photoCount'] as int,
      lastLayoutId: json['lastLayoutId'] as String?,
      lastRatio: json['lastRatio'] as String?,
      lastCoverFrameTimeMs: coverMs,
      lastBlockTransforms: blockTransforms,
      lastSpacing: (json['lastSpacing'] as num?)?.toDouble(),
      lastCornerRadius: (json['lastCornerRadius'] as num?)?.toDouble(),
      lastBackgroundColor: json['lastBackgroundColor'] as int?,
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
      if (lastLayoutId != null) 'lastLayoutId': lastLayoutId,
      if (lastRatio != null) 'lastRatio': lastRatio,
      if (lastCoverFrameTimeMs != null) 'lastCoverFrameTimeMs': lastCoverFrameTimeMs,
      if (lastBlockTransforms != null) 'lastBlockTransforms': lastBlockTransforms,
      if (lastSpacing != null) 'lastSpacing': lastSpacing,
      if (lastCornerRadius != null) 'lastCornerRadius': lastCornerRadius,
      if (lastBackgroundColor != null) 'lastBackgroundColor': lastBackgroundColor,
    };
  }

  /// 获取时间差描述
  String getTimeAgo(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return l10n.justNow;
    } else if (difference.inMinutes < 60) {
      return l10n.minAgo(difference.inMinutes);
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return hours > 1 ? l10n.hoursAgo(hours) : l10n.hourAgo(hours);
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return days > 1 ? l10n.daysAgo(days) : l10n.dayAgo(days);
    } else {
      final weeks = difference.inDays ~/ 7;
      return weeks > 1 ? l10n.weeksAgo(weeks) : l10n.weekAgo(weeks);
    }
  }
}
