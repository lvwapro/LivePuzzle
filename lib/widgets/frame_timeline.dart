import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:live_puzzle/models/live_photo.dart';
import 'package:live_puzzle/models/frame_data.dart';

/// 视频时间轴组件
/// 用于显示和选择Live Photo的帧
class FrameTimeline extends StatefulWidget {
  final LivePhoto livePhoto;
  final Duration? selectedTimestamp;
  final ValueChanged<Duration>? onTimestampChanged;
  final List<FrameData>? previewFrames;

  const FrameTimeline({
    Key? key,
    required this.livePhoto,
    this.selectedTimestamp,
    this.onTimestampChanged,
    this.previewFrames,
  }) : super(key: key);

  @override
  State<FrameTimeline> createState() => _FrameTimelineState();
}

class _FrameTimelineState extends State<FrameTimeline> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(widget.livePhoto.videoFile!);
    await _controller.initialize();
    setState(() {
      _isInitialized = true;
    });

    _controller.addListener(() {
      if (mounted) {
        setState(() {
          _currentPosition = _controller.value.position;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // 视频预览
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
        const SizedBox(height: 16),
        
        // 播放控制
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
              onPressed: () {
                setState(() {
                  if (_controller.value.isPlaying) {
                    _controller.pause();
                  } else {
                    _controller.play();
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.replay),
              onPressed: () {
                _controller.seekTo(Duration.zero);
                _controller.play();
              },
            ),
          ],
        ),
        
        // 时间轴滑块
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Slider(
                value: _currentPosition.inMilliseconds.toDouble(),
                min: 0,
                max: _controller.value.duration.inMilliseconds.toDouble(),
                onChanged: (value) {
                  final position = Duration(milliseconds: value.toInt());
                  _controller.seekTo(position);
                  widget.onTimestampChanged?.call(position);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(_currentPosition)),
                  Text(_formatDuration(_controller.value.duration)),
                ],
              ),
            ],
          ),
        ),
        
        // 帧预览列表
        if (widget.previewFrames != null)
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.previewFrames!.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final frame = widget.previewFrames![index];
                final isSelected =
                    widget.selectedTimestamp == frame.timestamp;
                return GestureDetector(
                  onTap: () {
                    _controller.seekTo(frame.timestamp);
                    widget.onTimestampChanged?.call(frame.timestamp);
                  },
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey,
                        width: isSelected ? 3 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.memory(
                      frame.imageData,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds =
        (duration.inMilliseconds % 1000 ~/ 10).toString().padLeft(2, '0');
    return '$minutes:$seconds.$milliseconds';
  }
}
