import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' as photo_manager;
import 'package:live_puzzle/providers/photo_provider.dart';
import 'package:live_puzzle/screens/puzzle_editor_screen.dart';
import 'package:live_puzzle/services/live_photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:live_puzzle/l10n/app_localizations.dart';

/// Live Photo选择页面 - Pick Moments风格
/// 支持iOS Live Photo和Android Motion Photo
/// 实现分页加载，避免内存溢出
class PhotoSelectionScreen extends ConsumerStatefulWidget {
  const PhotoSelectionScreen({super.key});

  @override
  ConsumerState<PhotoSelectionScreen> createState() =>
      _PhotoSelectionScreenState();
}

class _PhotoSelectionScreenState extends ConsumerState<PhotoSelectionScreen> {
  int _selectedTabIndex = 1; // 0: 全部, 1: 实况
  final ScrollController _scrollController = ScrollController();
  String? _selectedAlbumId; // 当前选中的相册ID
  List<photo_manager.AssetPathEntity> _albums = []; // 相册列表

  @override
  void initState() {
    super.initState();
    _loadAlbums();
    // 🔥 初始化时加载照片
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPhotos();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 加载相册列表
  Future<void> _loadAlbums() async {
    try {
      final albums = await photo_manager.PhotoManager.getAssetPathList(
        type: photo_manager.RequestType.common,
        hasAll: true,
      );
      // 🔥 只保留有照片的相册（根据当前 tab 过滤）
      final nonEmptyAlbums = <photo_manager.AssetPathEntity>[];
      for (final album in albums) {
        // 获取相册中的资源列表
        final assetList = await album.getAssetListRange(start: 0, end: 1);
        if (assetList.isNotEmpty) {
          // 如果是"实况"标签，额外检查是否有实况照片
          if (_selectedTabIndex == 1) {
            // 检查相册中是否有实况照片（使用 photo_manager 的 isLivePhoto 属性）
            final assets = await album.getAssetListRange(start: 0, end: 100);
            final hasLivePhoto = assets.any((asset) => 
              asset.type == photo_manager.AssetType.image && asset.isLivePhoto
            );
            if (hasLivePhoto) {
              nonEmptyAlbums.add(album);
            }
          } else {
            // "全部"标签，只要有照片就添加
            nonEmptyAlbums.add(album);
          }
        }
      }
      setState(() {
        _albums = nonEmptyAlbums;
      });
    } catch (e) {
      debugPrint('❌ 加载相册列表失败: $e');
    }
  }

  void _loadPhotos() {
    ref
        .read(livePhotoListProvider.notifier)
        .loadPhotos(filter: PhotoFilter.live);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final livePhotosAsync = ref.watch(livePhotoListProvider);
    // 🔥 根据当前tab使用对应的选中状态
    final selectedIds = _selectedTabIndex == 0
        ? ref.watch(selectedAllPhotoIdsProvider)
        : ref.watch(selectedLivePhotoIdsProvider);
    final livePhotoIdsSetAsync =
        ref.watch(livePhotoIdsSetProvider); // 🔥 获取实况照片ID集合

    return WillPopScope(
      // 🔥 返回时清空所有选中状态
      onWillPop: () async {
        ref.read(selectedAllPhotoIdsProvider.notifier).clear();
        ref.read(selectedLivePhotoIdsProvider.notifier).clear();
        return true; // 允许返回
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBFC), // app-bg
        body: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F3), // soft-pink
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF85A1).withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back Button
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 18,
                              color: Color(0xFFFF4D80),
                            ),
                            onPressed: () {
                              // 🔥 返回前清空所有选中状态
                              ref.read(selectedAllPhotoIdsProvider.notifier).clear();
                              ref.read(selectedLivePhotoIdsProvider.notifier).clear();
                              Navigator.pop(context);
                            },
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        // Title
                        Column(
                          children: [
                            Text(
                              l10n.pickMoments,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F1F1F),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4D80).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                l10n.selected(selectedIds.length),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF4D80),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Refresh Button
                        IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            size: 24,
                            color: Color(0xFFFF4D80),
                          ),
                          onPressed: () {
                            // 取消全部选中
                            ref.read(selectedAllPhotoIdsProvider.notifier).clear();
                            ref.read(selectedLivePhotoIdsProvider.notifier).clear();
                            // 刷新照片列表
                            _loadPhotos();
                          },
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  // 后台加载提示
                  if (_selectedTabIndex == 1 &&
                      ref.read(livePhotoListProvider.notifier).isLoadingMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFFF4D80).withOpacity(0.6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '正在后台加载更多...',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Tabs
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
                    child: Row(
                      children: [
                        _buildTab('全部', 0),
                        const SizedBox(width: 24),
                        _buildTab('实况', 1),
                      ],
                    ),
                  ),
                  // 相册分类
                  if (_albums.isNotEmpty)
                    Container(
                      height: 36,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _albums.length,
                        itemBuilder: (context, index) {
                          final album = _albums[index];
                          final isSelected = _selectedAlbumId == album.id ||
                              (_selectedAlbumId == null && album.isAll);
                          return _buildAlbumChip(album, isSelected);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Photo Grid
          Expanded(
            child: livePhotosAsync.when(
              data: (assets) {
                if (assets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '没有找到照片',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '请确保相册中有照片',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // 根据选中的标签显示照片
                // 注意：如果是"实况"标签，provider已经通过原生桥接过滤了，无需再次过滤
                final filteredAssets = assets;

                if (filteredAssets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedTabIndex == 1
                              ? Icons.motion_photos_off
                              : Icons.photo_library_outlined,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedTabIndex == 1 ? '没有找到实况照片' : '没有找到照片',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedTabIndex == 1 ? '请在相册中添加实况照片' : '请确保相册中有照片',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true, // 始终显示滚动条
                  thickness: 6.0, // 滚动条粗细
                  radius: const Radius.circular(3),
                  child: GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    // 🔥 添加缓存范围，减少重建
                    cacheExtent: 500, // 提前缓存500像素
                    addAutomaticKeepAlives: true, // 保持已构建的item
                    addRepaintBoundaries: true, // 每个item独立重绘
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 6, // 缩小间隙
                      mainAxisSpacing: 6, // 缩小间隙
                    ),
                    itemCount: filteredAssets.length,
                    itemBuilder: (context, index) {
                      final asset = filteredAssets[index];
                      final isSelected = selectedIds.contains(asset.id);
                      // 🔥 从缓存的集合中判断是否为实况照片
                      final isLivePhoto = livePhotoIdsSetAsync.when(
                        data: (livePhotoIdsSet) =>
                            livePhotoIdsSet.contains(asset.id),
                        loading: () => false,
                        error: (_, __) => false,
                      );

                      // 🔥 根据当前tab选择对应的provider
                      final selectionProvider = _selectedTabIndex == 0
                          ? selectedAllPhotoIdsProvider
                          : selectedLivePhotoIdsProvider;

                      return _buildPhotoItem(
                        asset,
                        isSelected,
                        isLivePhoto,
                        index,
                        filteredAssets,
                        selectionProvider, // 传入对应的provider
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4D80)),
                ),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text('加载失败'),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loadPhotos,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Continue Button
          if (selectedIds.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFFFBFC).withOpacity(0),
                    const Color(0xFFFFFBFC),
                    const Color(0xFFFFFBFC),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PuzzleEditorScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4D80),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: const Color(0xFFFF4D80).withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.continueButton,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      ), // 🔥 Scaffold 的结束
    ); // 🔥 WillPopScope 的结束
  }

  Widget _buildTab(String label, int tabIndex) {
    final isActive = _selectedTabIndex == tabIndex;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = tabIndex;
        });

        // 根据标签切换，重新加载相册列表和照片
        _loadAlbums(); // 🔥 重新加载相册列表以过滤没有照片的相册
        
        if (tabIndex == 0) {
          // 全部照片
          ref.read(livePhotoListProvider.notifier).loadPhotos(
                filter: PhotoFilter.all,
                albumId: _selectedAlbumId,
              );
        } else {
          // 实况照片
          ref.read(livePhotoListProvider.notifier).loadPhotos(
                filter: PhotoFilter.live,
                albumId: _selectedAlbumId,
              );
        }
      },
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? const Color(0xFFFF4D80) : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 4),
          if (isActive)
            Container(
              width: 24,
              height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D80),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlbumChip(photo_manager.AssetPathEntity album, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAlbumId = album.isAll ? null : album.id;
        });
        // 🔥 根据相册和Tab组合筛选照片
        final albumId = album.isAll ? null : album.id;
        ref.read(livePhotoListProvider.notifier).loadPhotos(
              filter:
                  _selectedTabIndex == 0 ? PhotoFilter.all : PhotoFilter.live,
              albumId: albumId,
            );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF4D80) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF4D80) : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF4D80).withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          _translateAlbumName(album.name),
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF2C2C2C), // 更深的颜色
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
  
  /// 翻译系统相册名称
  String _translateAlbumName(String name) {
    final l10n = AppLocalizations.of(context)!;
    switch (name.toLowerCase()) {
      case 'recents':
      case '最近项目':
      case '最近':
        return l10n.recents;
      case 'favorites':
      case '个人收藏':
      case '收藏':
        return l10n.favorites;
      case 'videos':
      case '视频':
        return l10n.videos;
      case 'selfies':
      case '自拍':
        return l10n.selfies;
      case 'live photos':
      case '实况照片':
        return l10n.livePhotos;
      case 'portrait':
      case 'portraits':
      case '人像':
        return l10n.portrait;
      case 'long exposure':
      case '长曝光':
        return l10n.longExposure;
      case 'panoramas':
      case '全景':
        return l10n.panoramas;
      case 'time-lapse':
      case 'timelapses':
      case '延时摄影':
        return l10n.timelapses;
      case 'slo-mo':
      case 'slomo':
      case '慢动作':
        return l10n.sloMo;
      case 'bursts':
      case '连拍快照':
        return l10n.bursts;
      case 'screenshots':
      case '屏幕快照':
        return l10n.screenshots;
      case 'all photos':
      case '所有照片':
        return l10n.allPhotos;
      default:
        return name; // 保留原名称
    }
  }

  /// 全屏查看图片，支持左右滑动
  void _showFullScreenGallery(
    BuildContext context,
    List<photo_manager.AssetEntity> assets,
    int initialIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenGallery(
          assets: assets,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildPhotoItem(
    photo_manager.AssetEntity asset,
    bool isSelected,
    bool isLivePhoto,
    int index,
    List<photo_manager.AssetEntity> allAssets,
    StateNotifierProvider<SelectedPhotoIdsNotifier, List<String>>
        selectionProvider, // 🔥 传入对应的选中状态provider
  ) {
    // 🔥 使用稳定的key，只基于asset.id，不包含选中状态
    // 这样选中状态变化时不会导致整个Widget重建
    final itemKey = ValueKey('photo_${asset.id}');
    
    return RepaintBoundary(
      key: itemKey,
      child: GestureDetector(
        onTap: () {
          // 🔥 使用传入的provider
          ref.read(selectionProvider.notifier).toggle(asset.id);
        },
        onLongPress: isLivePhoto
            ? () {
                // 长按播放实况照片
                _showLivePhotoPreview(asset);
              }
            : null,
        child: AnimatedContainer(
          // 使用 AnimatedContainer 让选中状态平滑过渡
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
              aspectRatio: 1, // 保持1:1正方形
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 🔥 Image - 使用独立的Widget避免重建
                  _PhotoThumbnail(
                    key: ValueKey('thumb_${asset.id}'),
                    asset: asset,
                  ),
                  // 实况照片标记（左上角）
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
                  // 放大图标（右下角）
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        // 全屏查看图片，支持左右滑动
                        _showFullScreenGallery(context, allAssets, index);
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
                  // 选中标记（右上角）- 使用AnimatedOpacity平滑过渡
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

  void _showLivePhotoPreview(photo_manager.AssetEntity asset) {
    showDialog(
      context: context,
      builder: (context) => _LivePhotoPreviewDialog(asset: asset),
    );
  }
}

/// 全屏图片查看器，支持左右滑动
class _FullScreenGallery extends StatefulWidget {
  final List<photo_manager.AssetEntity> assets;
  final int initialIndex;

  const _FullScreenGallery({
    required this.assets,
    required this.initialIndex,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, VideoPlayerController?> _videoControllers = {};
  final Map<int, bool> _isLivePhoto = {};
  final Map<int, bool> _isPlaying = {}; // 🔥 跟踪视频是否正在播放
  final Map<int, Uint8List?> _imageCache = {}; // 🔥 图片缓存

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    // 预加载当前和相邻图片
    _preloadImages(_currentIndex);
    _checkAndPlayLivePhoto(_currentIndex);
  }

  /// 预加载当前和相邻的图片
  Future<void> _preloadImages(int index) async {
    // 预加载当前、前一张、后一张图片
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
    // 释放所有视频控制器
    for (final controller in _videoControllers.values) {
      controller?.dispose();
    }
    super.dispose();
  }

  /// 检查并播放实况照片
  Future<void> _checkAndPlayLivePhoto(int index) async {
    final asset = widget.assets[index];

    // 检查是否为实况照片
    final isLive = await LivePhotoManager.isLivePhoto(asset);
    setState(() {
      _isLivePhoto[index] = isLive;
    });

    if (isLive) {
      _playLivePhoto(index);
    }
  }

  /// 播放实况照片
  Future<void> _playLivePhoto(int index) async {
    final asset = widget.assets[index];

    // 如果已有控制器，重置到开头并播放
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
        await controller.setLooping(false); // 🔥 只播放一次
        
        // 🔥 监听播放完成事件
        controller.addListener(() {
          if (mounted && 
              !controller.value.isPlaying && 
              controller.value.position >= controller.value.duration) {
            // 播放完成，切换回静态图片
            setState(() {
              _isPlaying[index] = false;
            });
          }
        });
        
        await controller.play();

        if (mounted) {
          setState(() {
            _videoControllers[index] = controller;
            _isPlaying[index] = true; // 标记为正在播放
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
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
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
          // 实况按钮（仅当当前照片是实况时显示）
          if (isCurrentLive)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  // 重新播放实况照片
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
          // 停止之前的视频并标记为未播放
          _videoControllers.forEach((key, controller) {
            if (key != index) {
              controller?.pause();
              _isPlaying[key] = false; // 🔥 标记为未播放
            }
          });
          // 预加载相邻图片
          _preloadImages(index);
          // 检查并播放新的实况照片
          _checkAndPlayLivePhoto(index);
        },
        itemBuilder: (context, index) {
          final asset = widget.assets[index];
          final videoController = _videoControllers[index];
          final isLive = _isLivePhoto[index] ?? false;
          final isPlaying = _isPlaying[index] ?? false; // 🔥 获取播放状态

          return Center(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 🔥 如果是实况、有视频控制器且正在播放，显示视频
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
                  // 否则显示静态图片 - 使用缓存，无loading
                  InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: _imageCache[index] != null
                        ? Image.memory(
                            _imageCache[index]!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true, // 🔥 无缝播放，避免闪烁
                          )
                        : FutureBuilder<Uint8List?>(
                            future: asset.originBytes,
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                // 缓存图片数据
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted && !_imageCache.containsKey(index)) {
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
                              // 🔥 只在首次加载且缓存未命中时显示loading
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

/// Live Photo 预览对话框
class _LivePhotoPreviewDialog extends StatefulWidget {
  final photo_manager.AssetEntity asset;

  const _LivePhotoPreviewDialog({required this.asset});

  @override
  State<_LivePhotoPreviewDialog> createState() =>
      _LivePhotoPreviewDialogState();
}

class _LivePhotoPreviewDialogState extends State<_LivePhotoPreviewDialog> {
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

/// 🔥 独立的缩略图Widget，避免因选中状态变化而重建
class _PhotoThumbnail extends StatefulWidget {
  final photo_manager.AssetEntity asset;

  const _PhotoThumbnail({super.key, required this.asset});

  @override
  State<_PhotoThumbnail> createState() => _PhotoThumbnailState();
}

class _PhotoThumbnailState extends State<_PhotoThumbnail>
    with AutomaticKeepAliveClientMixin {
  Uint8List? _cachedThumbnail;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true; // 🔥 保持状态，避免重建

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      // 🔥 使用正方形尺寸并设置format为ThumbnailFormat.jpeg
      // photo_manager会自动裁剪成正方形
      final thumbnail = await widget.asset.thumbnailDataWithSize(
        const photo_manager.ThumbnailSize.square(400), // 使用square确保正方形
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
    super.build(context); // 必须调用以支持 AutomaticKeepAliveClientMixin

    if (_cachedThumbnail != null) {
      return Image.memory(
        _cachedThumbnail!,
        fit: BoxFit.cover, // cover会填充整个区域，保持宽高比
        gaplessPlayback: true,
        // 🔥 移除 cacheWidth/Height，让图片按原尺寸显示，避免二次缩放导致变形
      );
    }

    // 加载中或失败
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

