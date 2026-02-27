import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_puzzle/screens/photo_selection_screen.dart';
import 'package:live_puzzle/screens/puzzle_editor_screen.dart';
import 'package:live_puzzle/screens/all_history_screen.dart';
import 'package:live_puzzle/utils/permissions.dart';
import 'package:live_puzzle/providers/puzzle_history_provider.dart';
import 'package:live_puzzle/providers/photo_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:live_puzzle/l10n/app_localizations.dart';

/// 主页面 - 可爱粉色风格
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F3), // soft-pink
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header with gradient background
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.helloMaker,
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFF85A2), // strawberry
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.readyToCreate,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B7280),
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20), // 增加顶部间距

                    // Start New Puzzle - 3D Button with decorations
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // 3D shadow layer
                          Positioned(
                            top: 8,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE66A85),
                                borderRadius: BorderRadius.circular(48),
                              ),
                            ),
                          ),
                          // Main Button
                          ClipRRect(
                            borderRadius: BorderRadius.circular(48),
                            child: Container(
                              width: double.infinity,
                              height: 200,
                              child: Material(
                                color: const Color(0xFFFF85A2),
                                child: InkWell(
                                  onTap: _isLoading ? null : _startCreating,
                                  child: Stack(
                                    children: [
                                      // Decorative circles
                                      Positioned(
                                        top: -24,
                                        left: -24,
                                        child: Container(
                                          width: 96,
                                          height: 96,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color:
                                                Colors.white.withOpacity(0.2),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: -40,
                                        right: -24,
                                        child: Container(
                                          width: 128,
                                          height: 128,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color:
                                                Colors.white.withOpacity(0.1),
                                          ),
                                        ),
                                      ),
                                      // Main content
                                      Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            // Camera icon in white circle
                                            Container(
                                              width: 64,
                                              height: 64,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.15),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.photo_camera,
                                                color: Color(0xFFFF85A2),
                                                size: 32,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.add,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  l10n.newPuzzle,
                                                  style: TextStyle(
                                                    fontFamily: 'Fredoka',
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                    letterSpacing: 0,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Heart decoration - 最外层，不会被裁剪
                          Positioned(
                            top: -12,
                            right: 8,
                            child: Transform.rotate(
                              angle: 0.3,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.favorite,
                                  color: Color(0xFFFF85A2),
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Inspiration Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.inspiration,
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          Icon(
                            Icons.auto_fix_high,
                            color: const Color(0xFFFF85A2),
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Inspiration Cards with kawaii shadows
                    SizedBox(
                      height: 240,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        physics: const BouncingScrollPhysics(),
                        itemCount: 3,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Container(
                              width: 140,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF85A2)
                                        .withOpacity(0.4),
                                    blurRadius: 30,
                                    offset: const Offset(0, 12),
                                    spreadRadius: -10,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFFFFD1DC)
                                            .withOpacity(0.3),
                                        const Color(0xFFFF85A2)
                                            .withOpacity(0.2),
                                      ],
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.image,
                                      size: 48,
                                      color: Color(0xFFFF85A2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 40),

                    // My Studio Section - 只在有历史记录时显示
                    Consumer(
                      builder: (context, ref, child) {
                        final histories = ref.watch(puzzleHistoryProvider);

                        if (histories.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final recentHistories = histories.take(4).toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    l10n.myStudio,
                                    style: TextStyle(
                                      fontFamily: 'Fredoka',
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const AllHistoryScreen(),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        l10n.viewAll,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFFF85A2),
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 20,
                                  crossAxisSpacing: 20,
                                  childAspectRatio: 1.0, // 正方形卡片
                                ),
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: recentHistories.length,
                                itemBuilder: (context, index) {
                                  final history = recentHistories[index];
                                  return _buildHistoryCard(history);
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 140),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(history) {
    return GestureDetector(
      onTap: () => _openHistoryEditor(history),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF85A2).withOpacity(0.4),
              blurRadius: 30,
              offset: const Offset(0, 12),
              spreadRadius: -10,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              // 背景图片或渐变
              Container(
                decoration: BoxDecoration(
                  gradient: history.thumbnail == null
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFFFD1DC).withOpacity(0.3),
                            const Color(0xFFFF85A2).withOpacity(0.2),
                          ],
                        )
                      : null,
                  image: history.thumbnail != null
                      ? DecorationImage(
                          image: MemoryImage(history.thumbnail!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: history.thumbnail == null
                    ? const Center(
                        child: Icon(
                          Icons.image,
                          size: 48,
                          color: Color(0xFFFF85A2),
                        ),
                      )
                    : null,
              ),

              // 左下角时间标签
              Positioned(
                left: 12,
                bottom: 12,
                child: Text(
                  history.getTimeAgo(context),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 打开历史记录进入编辑器
  Future<void> _openHistoryEditor(history) async {
    // 加载这些照片的 AssetEntity
    final selectedAssets = <AssetEntity>[];

    for (final photoId in history.photoIds) {
      try {
        final asset = await AssetEntity.fromId(photoId);
        if (asset != null) {
          selectedAssets.add(asset);
        }
      } catch (e) {
        print('无法加载照片 $photoId: $e');
      }
    }

    if (selectedAssets.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('照片已被删除或无法访问'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 更新选中的照片ID到provider
    if (mounted) {
      ref.read(selectedLivePhotoIdsProvider.notifier).setIds(
            selectedAssets.map((a) => a.id).toList(),
          );

      // 导航到编辑器
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PuzzleEditorScreen(),
        ),
      );
    }
  }

  Widget _buildRecentCard(String title, String timeAgo) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF85A2).withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 12),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFFD1DC).withOpacity(0.3),
                    const Color(0xFFFF85A2).withOpacity(0.2),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.image,
                  size: 48,
                  color: Color(0xFFFF85A2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 10,
                      color: const Color(0xFFFF85A2),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startCreating() async {
    setState(() {
      _isLoading = true;
    });

    // 请求权限
    final hasPermission = await PermissionHelper.requestAllPermissions();

    setState(() {
      _isLoading = false;
    });

    if (!hasPermission) {
      if (!mounted) return;

      // 显示权限说明对话框
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('需要相册权限'),
          content: const Text(
            '此应用需要访问您的照片库来选择Live Photo。\n\n'
            '请点击"允许"按钮授予权限，或点击"去设置"在设置中手动开启。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final granted =
                    await PermissionHelper.requestPhotoLibraryPermission();
                if (granted && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PhotoSelectionScreen(),
                    ),
                  );
                }
              },
              child: const Text('允许'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await PermissionHelper.openSettings();
              },
              child: const Text('去设置'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PhotoSelectionScreen(),
      ),
    );
  }
}
