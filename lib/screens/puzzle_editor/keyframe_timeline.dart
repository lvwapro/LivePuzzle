import 'package:flutter/material.dart';

/// 关键帧数据模型
class Keyframe {
  final int id;
  final double time; // 时间点（秒）
  final String? thumbnail; // 缩略图路径（可选）

  Keyframe({
    required this.id,
    required this.time,
    this.thumbnail,
  });
}

/// 关键帧管理条
class KeyframeTimeline extends StatelessWidget {
  final List<Keyframe> keyframes;
  final int? selectedKeyframeId;
  final Function(int) onKeyframeTap;
  final Function(int) onKeyframeLongPress;
  final VoidCallback onAddKeyframe;

  const KeyframeTimeline({
    super.key,
    required this.keyframes,
    this.selectedKeyframeId,
    required this.onKeyframeTap,
    required this.onKeyframeLongPress,
    required this.onAddKeyframe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,  // 增加高度以容纳内容
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F3).withOpacity(0.5),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFFF85A2).withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          // 关键帧列表
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: keyframes.length,
              itemBuilder: (context, index) {
                final keyframe = keyframes[index];
                final isSelected = selectedKeyframeId == keyframe.id;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => onKeyframeTap(keyframe.id),
                    onLongPress: () => onKeyframeLongPress(keyframe.id),
                    child: SizedBox(
                      width: 48,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 帧缩略图
                          Container(
                            width: 48,
                            height: 40,  // 减小高度
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD1DC).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFFF85A2)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? const Color(0xFFFF85A2)
                                      : const Color(0xFF9CA3AF),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          // 时间标签
                          Text(
                            '${keyframe.time.toStringAsFixed(1)}s',
                            style: TextStyle(
                              fontSize: 9,
                              color: isSelected
                                  ? const Color(0xFFFF85A2)
                                  : const Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // 添加按钮
          GestureDetector(
            onTap: onAddKeyframe,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFF85A2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFF85A2),
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: const Icon(
                Icons.add,
                color: Color(0xFFFF85A2),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
