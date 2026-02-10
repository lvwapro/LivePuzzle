import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 🔥 基于视频播放器的帧选择器 - 流畅拖动
class VideoFrameSelectorWidget extends StatefulWidget {
  final VideoPlayerController videoController;
  final bool isCover;
  final VoidCallback onSetCover;

  const VideoFrameSelectorWidget({
    super.key,
    required this.videoController,
    required this.isCover,
    required this.onSetCover,
  });

  @override
  State<VideoFrameSelectorWidget> createState() => _VideoFrameSelectorWidgetState();
}

class _VideoFrameSelectorWidgetState extends State<VideoFrameSelectorWidget> {
  double _currentPosition = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    widget.videoController.addListener(_updatePosition);
    _currentPosition = widget.videoController.value.position.inMilliseconds.toDouble();
  }

  @override
  void dispose() {
    widget.videoController.removeListener(_updatePosition);
    super.dispose();
  }

  void _updatePosition() {
    if (!_isDragging && mounted) {
      setState(() {
        _currentPosition = widget.videoController.value.position.inMilliseconds.toDouble();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.videoController.value.duration.inMilliseconds.toDouble();
    final position = _currentPosition.clamp(0.0, duration);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 标题和封面标识
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '设为封面照片',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A3F44),
                ),
              ),
              if (widget.isCover) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D7D),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '当前封面',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // 视频预览
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
              border: widget.isCover
                  ? Border.all(color: const Color(0xFFFF4D7D), width: 3)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: widget.videoController.value.isInitialized
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: widget.videoController.value.size.width,
                        height: widget.videoController.value.size.height,
                        child: VideoPlayer(widget.videoController),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF4D7D),
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 20),

          // 设置为封面按钮
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: widget.onSetCover,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D7D),
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: const Color(0xFFFF4D7D).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isCover ? Icons.refresh : Icons.star,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isCover ? '重新设置封面' : '设置为封面',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 滑动选择器 - 视频进度条
          Column(
            children: [
              // 时间指示
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(position / 1000).toStringAsFixed(2)}s',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4A3F44),
                      ),
                    ),
                    Text(
                      '${(duration / 1000).toStringAsFixed(2)}s',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 滑块 - 视频进度条
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: const Color(0xFFFF4D7D),
                  inactiveTrackColor: Colors.grey.shade300,
                  thumbColor: Colors.white,
                  overlayColor: const Color(0xFFFF4D7D).withOpacity(0.2),
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 12,
                    elevation: 4,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 20,
                  ),
                ),
                child: Slider(
                  value: position,
                  min: 0,
                  max: duration > 0 ? duration : 1,
                  onChangeStart: (value) {
                    setState(() {
                      _isDragging = true;
                    });
                  },
                  onChanged: (value) {
                    setState(() {
                      _currentPosition = value;
                    });
                    widget.videoController.seekTo(Duration(milliseconds: value.toInt()));
                  },
                  onChangeEnd: (value) {
                    setState(() {
                      _isDragging = false;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 提示文字
          Text(
            '拖动进度条预览，点击"设置为封面"保存当前帧',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
