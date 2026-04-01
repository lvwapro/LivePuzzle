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
import 'package:live_puzzle/screens/image_split_screen.dart';
import 'home/home_history_card.dart';

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

                    // 功能入口：新拼图 + 切图
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: _FeatureCard(
                              icon: Icons.photo_camera,
                              label: l10n.newPuzzle,
                              color: const Color(0xFFFF85A2),
                              shadowColor: const Color(0xFFE66A85),
                              onTap: _isLoading ? null : _startCreating,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _FeatureCard(
                              icon: Icons.grid_view_rounded,
                              label: l10n.imageSplit,
                              color: const Color(0xFF85C1E9),
                              shadowColor: const Color(0xFF5DADE2),
                              onTap: _isLoading ? null : _startSplitting,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // My Studio Section - 有历史显示列表，无历史显示占位
                    Consumer(
                      builder: (context, ref, child) {
                        final histories = ref.watch(puzzleHistoryProvider);

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
                                  if (histories.isNotEmpty)
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
                                          borderRadius:
                                              BorderRadius.circular(20),
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
                            if (histories.isEmpty)
                              const HomeHistoryEmptyPlaceholder()
                            else
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 20,
                                    crossAxisSpacing: 20,
                                    childAspectRatio: 1.0,
                                  ),
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: histories.take(4).toList().length,
                                  itemBuilder: (context, index) {
                                    final history =
                                        histories.take(4).toList()[index];
                                    return HomeHistoryCard(
                                      history: history,
                                      onTap: () => _openHistoryEditor(history),
                                    );
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

      // 导航到编辑器（传入 history 以便恢复上次布局与封面帧）
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PuzzleEditorScreen(),
          settings: RouteSettings(arguments: history),
        ),
      );
    }
  }

  Future<void> _startSplitting() async {
    setState(() => _isLoading = true);
    final hasPermission = await PermissionHelper.requestAllPermissions();
    setState(() => _isLoading = false);

    if (!hasPermission) {
      if (!mounted) return;
      _showPermissionDialog(
        onGranted: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ImageSplitScreen(),
            ),
          );
        },
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ImageSplitScreen(),
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
      _showPermissionDialog(
        onGranted: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PhotoSelectionScreen(),
            ),
          );
        },
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

  void _showPermissionDialog({required VoidCallback onGranted}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('需要相册权限'),
        content: const Text(
          '此应用需要访问您的照片库来选择照片。\n\n'
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
              if (granted && mounted) onGranted();
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
  }
}

/// 首页功能入口卡片
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color shadowColor;
  final VoidCallback? onTap;

  const _FeatureCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.shadowColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 3D 阴影层
        Positioned(
          top: 6,
          left: 0,
          right: 0,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: shadowColor,
              borderRadius: BorderRadius.circular(32),
            ),
          ),
        ),
        // 主按钮
        ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: SizedBox(
            width: double.infinity,
            height: 160,
            child: Material(
              color: color,
              child: InkWell(
                onTap: onTap,
                child: Stack(
                  children: [
                    Positioned(
                      top: -16,
                      left: -16,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -28,
                      right: -16,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(icon, color: color, size: 26),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            label,
                            style: const TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
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
      ],
    );
  }
}
