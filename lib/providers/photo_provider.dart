import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:live_puzzle/services/live_photo_manager.dart';
import 'package:live_photo_bridge/live_photo_bridge.dart';

enum PhotoFilter { all, live }

/// 实况照片ID集合缓存
final livePhotoIdsSetProvider = FutureProvider<Set<String>>((ref) async {
  // 直接从原生桥接获取所有实况照片的ID
  final livePhotoIds = await LivePhotoBridge.getLivePhotoIds();
  return livePhotoIds.toSet();
});

/// Live Photo列表状态
final livePhotoListProvider =
    StateNotifierProvider<LivePhotoListNotifier, AsyncValue<List<AssetEntity>>>(
  (ref) => LivePhotoListNotifier(ref),
);

class LivePhotoListNotifier
    extends StateNotifier<AsyncValue<List<AssetEntity>>> {
  PhotoFilter _currentFilter = PhotoFilter.live; // 默认实况标签
  bool _isLoadingMore = false; // 是否正在后台加载更多
  int _totalLivePhotoCount = 0; // 实况照片总数
  int _totalAllPhotoCount = 0; // 全部照片总数
  String? _currentAlbumId; // 当前选中的相册ID

  LivePhotoListNotifier(Ref ref) : super(const AsyncValue.loading()) {
    // 🔥 不在构造函数中自动加载，让页面控制何时加载
    // loadPhotos();
  }

  PhotoFilter get currentFilter => _currentFilter;
  bool get isLoadingMore => _isLoadingMore;
  int get totalCount => _currentFilter == PhotoFilter.live 
      ? _totalLivePhotoCount 
      : _totalAllPhotoCount;
  String? get currentAlbumId => _currentAlbumId;

  Future<void> loadPhotos({PhotoFilter? filter, String? albumId}) async {
    // 🔥 优化：如果只是切换相册，保持当前数据，避免闪烁
    final isAlbumSwitch = filter == null && albumId != _currentAlbumId;
    if (!isAlbumSwitch) {
      state = const AsyncValue.loading();
    }
    
    if (filter != null) {
      _currentFilter = filter;
    }
    if (albumId != null) {
      _currentAlbumId = albumId;
    }

    try {
      List<AssetEntity> photos;
      if (_currentFilter == PhotoFilter.live) {
        // 🚀 快速加载：先加载前 250 张实况照片
        debugPrint(
            '🚀 快速加载前 250 张实况照片... ${_currentAlbumId != null ? "相册ID: $_currentAlbumId" : "所有相册"}');
        photos = await LivePhotoManager.getLivePhotosOnly(
          limit: 250,
          albumId: _currentAlbumId,
        );

        // 获取总数
        final allIds = await LivePhotoBridge.getLivePhotoIds();
        _totalLivePhotoCount = allIds.length;

        debugPrint('✅ 前 250 张加载完成，总共 $_totalLivePhotoCount 张实况照片');

        // 先更新UI显示前250张
        state = AsyncValue.data(photos);

        // 如果还有更多，后台继续加载
        if (photos.length < _totalLivePhotoCount && _currentAlbumId == null) {
          debugPrint(
              '📥 后台继续加载剩余 ${_totalLivePhotoCount - photos.length} 张...');
          _loadRemainingPhotos();
        }
      } else {
        // 🚀 全部照片：先快速加载前 400 张
        debugPrint(
            '🚀 快速加载前 400 张照片... ${_currentAlbumId != null ? "相册ID: $_currentAlbumId" : "所有相册"}');
        photos = await LivePhotoManager.getAllPhotos(
          albumId: _currentAlbumId,
          limit: 400,
        );

        // 获取总数
        final pathList = await PhotoManager.getAssetPathList(
          type: RequestType.image,
          hasAll: true,
        );
        if (pathList.isNotEmpty) {
          if (_currentAlbumId != null) {
            final album = pathList.firstWhere(
              (path) => path.id == _currentAlbumId,
              orElse: () => pathList.first,
            );
            _totalAllPhotoCount = await album.assetCountAsync;
          } else {
            _totalAllPhotoCount = await pathList.first.assetCountAsync;
          }
        }

        debugPrint('✅ 前 400 张加载完成，总共 $_totalAllPhotoCount 张照片');

        // 先更新UI显示前400张
        state = AsyncValue.data(photos);

        // 如果还有更多，后台继续加载
        if (photos.length < _totalAllPhotoCount) {
          debugPrint(
              '📥 后台继续加载剩余 ${_totalAllPhotoCount - photos.length} 张...');
          _loadRemainingPhotos();
        }
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// 后台加载剩余照片
  Future<void> _loadRemainingPhotos() async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;

    try {
      final currentPhotos = state.value ?? [];
      debugPrint('📥 后台加载剩余照片，当前已有 ${currentPhotos.length} 张');

      List<AssetEntity> allPhotos;
      if (_currentFilter == PhotoFilter.live) {
        // 加载全部实况照片
        allPhotos = await LivePhotoManager.getLivePhotosOnly(
          albumId: _currentAlbumId,
        );
        debugPrint('✅ 后台加载完成！总共 ${allPhotos.length} 张实况照片');
      } else {
        // 加载全部照片
        allPhotos = await LivePhotoManager.getAllPhotos(
          albumId: _currentAlbumId,
        );
        debugPrint('✅ 后台加载完成！总共 ${allPhotos.length} 张照片');
      }

      // 更新状态
      state = AsyncValue.data(allPhotos);
    } catch (e) {
      debugPrint('❌ 后台加载失败: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refresh() async {
    await loadPhotos(filter: _currentFilter, albumId: _currentAlbumId);
  }
}

/// 选中的Live Photo状态
final selectedLivePhotoProvider = StateProvider<AssetEntity?>((ref) => null);

/// 🔥 全部照片的选中ID列表
final selectedAllPhotoIdsProvider =
    StateNotifierProvider<SelectedPhotoIdsNotifier, List<String>>(
  (ref) => SelectedPhotoIdsNotifier(),
);

/// 🔥 实况照片的选中ID列表
final selectedLivePhotoIdsProvider =
    StateNotifierProvider<SelectedPhotoIdsNotifier, List<String>>(
  (ref) => SelectedPhotoIdsNotifier(),
);

class SelectedPhotoIdsNotifier extends StateNotifier<List<String>> {
  SelectedPhotoIdsNotifier() : super([]);

  void add(String id) {
    if (!state.contains(id)) {
      state = [...state, id];
    }
  }

  void remove(String id) {
    state = state.where((item) => item != id).toList();
  }

  void toggle(String id) {
    if (state.contains(id)) {
      remove(id);
    } else {
      add(id);
    }
  }

  void clear() {
    state = [];
  }

  bool contains(String id) {
    return state.contains(id);
  }
}
