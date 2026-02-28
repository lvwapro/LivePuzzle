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

  const PuzzleHistory({
    required this.id,
    required this.photoIds,
    required this.createdAt,
    this.thumbnail,
    required this.photoCount,
    this.lastLayoutId,
    this.lastRatio,
    this.lastCoverFrameTimeMs,
  });

  /// 从JSON创建
  factory PuzzleHistory.fromJson(Map<String, dynamic> json) {
    List<int>? coverMs;
    if (json['lastCoverFrameTimeMs'] != null) {
      coverMs = (json['lastCoverFrameTimeMs'] as List).cast<int>();
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
