import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart' as photo_manager;

/// 独立的缩略图Widget，避免因选中状态变化而重建
class PhotoThumbnail extends StatefulWidget {
  final photo_manager.AssetEntity asset;

  const PhotoThumbnail({super.key, required this.asset});

  @override
  State<PhotoThumbnail> createState() => _PhotoThumbnailState();
}

class _PhotoThumbnailState extends State<PhotoThumbnail>
    with AutomaticKeepAliveClientMixin {
  Uint8List? _cachedThumbnail;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      final thumbnail = await widget.asset.thumbnailDataWithSize(
        const photo_manager.ThumbnailSize.square(400),
        quality: 85,
        format: photo_manager.ThumbnailFormat.jpeg,
      );
      if (mounted) {
        setState(() {
          _cachedThumbnail = thumbnail;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 加载缩略图失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_cachedThumbnail != null) {
      return Image.memory(
        _cachedThumbnail!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    return Container(
      color: const Color(0xFFFFF0F3),
      child: _isLoading
          ? null
          : const Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 32,
            ),
    );
  }
}
