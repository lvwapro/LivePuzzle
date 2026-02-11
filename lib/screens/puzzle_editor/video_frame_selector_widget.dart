import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 帧选择器 - 紧凑模式，拖动进度条直接在编辑区预览
class VideoFrameSelectorWidget extends StatefulWidget {
  final VideoPlayerController videoController;
  final bool isCover;
  final ScrollController scrollController;
  final ValueChanged<int> onFrameTimeChanged; // 滑动时实时回调时间（毫秒）
  final VoidCallback onConfirm; // 确定设置封面
  final VoidCallback onCancel; // 取消，恢复原图

  const VideoFrameSelectorWidget({
    super.key,
    required this.videoController,
    required this.isCover,
    required this.scrollController,
    required this.onFrameTimeChanged,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<VideoFrameSelectorWidget> createState() =>
      _VideoFrameSelectorWidgetState();
}

class _VideoFrameSelectorWidgetState extends State<VideoFrameSelectorWidget> {
  double _currentPosition = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    widget.videoController.addListener(_updatePosition);
    _currentPosition =
        widget.videoController.value.position.inMilliseconds.toDouble();
  }

  @override
  void dispose() {
    widget.videoController.removeListener(_updatePosition);
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoFrameSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoController != widget.videoController) {
      oldWidget.videoController.removeListener(_updatePosition);
      widget.videoController.addListener(_updatePosition);
      _currentPosition =
          widget.videoController.value.position.inMilliseconds.toDouble();
    }
  }

  void _updatePosition() {
    if (!_isDragging && mounted) {
      setState(() {
        _currentPosition =
            widget.videoController.value.position.inMilliseconds.toDouble();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration =
        widget.videoController.value.duration.inMilliseconds.toDouble();
    final position = _currentPosition.clamp(0.0, duration);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: ListView(
        controller: widget.scrollController,
        padding: EdgeInsets.zero,
        children: [
          // ━━━ 拖拽手柄 ━━━
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ━━━ 标题行 ━━━
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  '选择定格帧',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A3F44),
                  ),
                ),
                if (widget.isCover) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D7D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '已设封面',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '拖动滑块在编辑区实时预览',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // ━━━ 时长 + 进度条 一行 ━━━
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 42,
                  child: Text(
                    '${(position / 1000).toStringAsFixed(1)}s',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A3F44),
                    ),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: const Color(0xFFFF4D7D),
                      inactiveTrackColor: Colors.grey.shade200,
                      thumbColor: Colors.white,
                      overlayColor: const Color(0x33FF4D7D),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                        elevation: 3,
                      ),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 16),
                    ),
                    child: Slider(
                      value: position,
                      min: 0,
                      max: duration > 0 ? duration : 1,
                      onChangeStart: (_) =>
                          setState(() => _isDragging = true),
                      onChanged: (v) {
                        setState(() => _currentPosition = v);
                        widget.videoController
                            .seekTo(Duration(milliseconds: v.toInt()));
                        // 实时通知父组件更新编辑区
                        widget.onFrameTimeChanged(v.toInt());
                      },
                      onChangeEnd: (v) {
                        setState(() => _isDragging = false);
                        // 拖动结束时再通知一次确保最终帧准确
                        widget.onFrameTimeChanged(v.toInt());
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${(duration / 1000).toStringAsFixed(1)}s',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // ━━━ 确定 / 取消 按钮 ━━━
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                // 取消按钮
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4A3F44),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '取消',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 确定按钮
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: widget.onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4D7D),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: const Color(0x4DFF4D7D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.isCover
                                ? Icons.refresh_rounded
                                : Icons.star_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.isCover ? '重新设置' : '确定设为封面',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
