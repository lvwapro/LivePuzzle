import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart' as photo_manager;
import 'package:live_puzzle/services/live_photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:live_puzzle/l10n/app_localizations.dart';

/// 全屏图片查看器，支持左右滑动
class FullScreenGallery extends StatefulWidget {
  final List<photo_manager.AssetEntity> assets;
  final int initialIndex;

  const FullScreenGallery({
    super.key,
    required this.assets,
    required this.initialIndex,
  });

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, VideoPlayerController?> _videoControllers = {};
  final Map<int, bool> _isLivePhoto = {};
  final Map<int, bool> _isPlaying = {};
  final Map<int, Uint8List?> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _preloadImages(_currentIndex);
    _checkAndPlayLivePhoto(_currentIndex);
  }

  Future<void> _preloadImages(int index) async {
    final indicesToLoad = [
      index,
      if (index > 0) index - 1,
      if (index < widget.assets.length - 1) index + 1,
    ];

    for (final i in indicesToLoad) {
      if (!_imageCache.containsKey(i)) {
        try {
          final bytes = await widget.assets[i].originBytes;
          if (mounted) {
            setState(() {
              _imageCache[i] = bytes;
            });
          }
        } catch (e) {
          debugPrint('❌ 预加载图片失败 [$i]: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _videoControllers.values) {
      controller?.dispose();
    }
    super.dispose();
  }

  Future<void> _checkAndPlayLivePhoto(int index) async {
    final asset = widget.assets[index];
    final isLive = await LivePhotoManager.isLivePhoto(asset);
    setState(() {
      _isLivePhoto[index] = isLive;
    });

    if (isLive) {
      _playLivePhoto(index);
    }
  }

  Future<void> _playLivePhoto(int index) async {
    final asset = widget.assets[index];

    if (_videoControllers[index] != null) {
      final controller = _videoControllers[index]!;
      await controller.seekTo(Duration.zero);
      await controller.play();
      setState(() {
        _isPlaying[index] = true;
      });
      return;
    }

    try {
      final videoFile = await LivePhotoManager.getVideoFile(asset);
      if (videoFile != null && mounted) {
        final controller = VideoPlayerController.file(videoFile);
        await controller.initialize();
        await controller.setLooping(false);

        controller.addListener(() {
          if (mounted &&
              !controller.value.isPlaying &&
              controller.value.position >= controller.value.duration) {
            setState(() {
              _isPlaying[index] = false;
            });
          }
        });

        await controller.play();

        if (mounted) {
          setState(() {
            _videoControllers[index] = controller;
            _isPlaying[index] = true;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ 播放实况照片失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isCurrentLive = _isLivePhoto[_currentIndex] ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.assets.length}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          if (isCurrentLive)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D80),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/live-icon.png',
                        width: 18,
                        height: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.live,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                onPressed: () {
                  _playLivePhoto(_currentIndex);
                },
              ),
            ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.assets.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
          _videoControllers.forEach((key, controller) {
            if (key != index) {
              controller?.pause();
              _isPlaying[key] = false;
            }
          });
          _preloadImages(index);
          _checkAndPlayLivePhoto(index);
        },
        itemBuilder: (context, index) {
          final asset = widget.assets[index];
          final videoController = _videoControllers[index];
          final isLive = _isLivePhoto[index] ?? false;
          final isPlaying = _isPlaying[index] ?? false;

          return Center(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isLive &&
                    isPlaying &&
                    videoController != null &&
                    videoController.value.isInitialized)
                  Center(
                    child: AspectRatio(
                      aspectRatio: videoController.value.aspectRatio,
                      child: VideoPlayer(videoController),
                    ),
                  )
                else
                  InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: _imageCache[index] != null
                        ? Image.memory(
                            _imageCache[index]!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          )
                        : FutureBuilder<Uint8List?>(
                            future: asset.originBytes,
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (mounted &&
                                      !_imageCache.containsKey(index)) {
                                    setState(() {
                                      _imageCache[index] = snapshot.data;
                                    });
                                  }
                                });
                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                );
                              }
                              return Container(
                                color: Colors.black,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
