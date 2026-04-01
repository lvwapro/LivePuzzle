import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart' as photo_manager;
import 'package:live_puzzle/services/live_photo_manager.dart';
import 'package:video_player/video_player.dart';

/// Live Photo 预览对话框
class LivePhotoPreviewDialog extends StatefulWidget {
  final photo_manager.AssetEntity asset;

  const LivePhotoPreviewDialog({super.key, required this.asset});

  @override
  State<LivePhotoPreviewDialog> createState() => _LivePhotoPreviewDialogState();
}

class _LivePhotoPreviewDialogState extends State<LivePhotoPreviewDialog> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final file = await LivePhotoManager.getVideoFile(widget.asset);
      if (file != null) {
        _controller = VideoPlayerController.file(file);
        await _controller!.initialize();
        await _controller!.setLooping(true);
        await _controller!.play();

        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ 初始化视频播放器失败: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: _isInitialized && _controller != null
          ? AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            )
          : const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
    );
  }
}
