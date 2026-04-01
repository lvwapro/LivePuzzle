import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' as photo_manager;
import 'package:live_puzzle/providers/photo_provider.dart';
import 'photo_thumbnail_widget.dart';
import 'fullscreen_gallery.dart';
import 'live_photo_preview_dialog.dart';

class PhotoGridItem extends ConsumerWidget {
  final photo_manager.AssetEntity asset;
  final bool isSelected;
  final bool isLivePhoto;
  final int index;
  final List<photo_manager.AssetEntity> allAssets;
  final StateNotifierProvider<SelectedPhotoIdsNotifier, List<String>>
      selectionProvider;

  const PhotoGridItem({
    super.key,
    required this.asset,
    required this.isSelected,
    required this.isLivePhoto,
    required this.index,
    required this.allAssets,
    required this.selectionProvider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RepaintBoundary(
      key: ValueKey('photo_${asset.id}'),
      child: GestureDetector(
        onTap: () {
          ref.read(selectionProvider.notifier).toggle(asset.id);
        },
        onLongPress: isLivePhoto
            ? () {
                showDialog(
                  context: context,
                  builder: (context) =>
                      LivePhotoPreviewDialog(asset: asset),
                );
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFFFF0F3),
            boxShadow: isSelected
                ? [
                    const BoxShadow(
                      color: Color(0xFFFF4D80),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PhotoThumbnail(
                    key: ValueKey('thumb_${asset.id}'),
                    asset: asset,
                  ),
                  if (isLivePhoto)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Image.asset(
                        'assets/images/live-icon.png',
                        width: 24,
                        height: 24,
                      ),
                    ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FullScreenGallery(
                              assets: allAssets,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.zoom_out_map,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isSelected ? 1.0 : 0.0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4D80),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
