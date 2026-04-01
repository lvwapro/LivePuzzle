import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' as photo_manager;
import 'package:live_puzzle/providers/photo_provider.dart';
import 'package:live_puzzle/screens/puzzle_editor_screen.dart';
import 'package:live_puzzle/l10n/app_localizations.dart';
import 'photo_selection/fullscreen_gallery.dart';
import 'photo_selection/live_photo_preview_dialog.dart';
import 'photo_selection/photo_thumbnail_widget.dart';

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
                        _buildTab(AppLocalizations.of(context)!.tabAll, 0),
                        const SizedBox(width: 24),
                        _buildTab(AppLocalizations.of(context)!.tabLivePhotos, 1),
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
                          _selectedTabIndex == 1 ? AppLocalizations.of(context)!.noLivePhotosFound : AppLocalizations.of(context)!.noPhotosFound,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedTabIndex == 1 ? AppLocalizations.of(context)!.pleaseAddLivePhotos : AppLocalizations.of(context)!.pleaseAddPhotos,
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
        builder: (context) => FullScreenGallery(
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
                  PhotoThumbnail(
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
      builder: (context) => LivePhotoPreviewDialog(asset: asset),
    );
  }
}

