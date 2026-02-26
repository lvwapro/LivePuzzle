import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_puzzle/providers/puzzle_history_provider.dart';
import 'package:live_puzzle/screens/puzzle_editor_screen.dart';
import 'package:live_puzzle/providers/photo_provider.dart';
import 'package:photo_manager/photo_manager.dart';

/// 全部历史记录页面
class AllHistoryScreen extends ConsumerWidget {
  const AllHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histories = ref.watch(puzzleHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F3),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
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
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Title
                  const Text(
                    'My Studio',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: histories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.photo_library_outlined,
                            size: 64,
                            color: Color(0xFFFF85A2),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '暂无历史记录',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '创建第一个拼图吧！',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 20,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: histories.length,
                      itemBuilder: (context, index) {
                        final history = histories[index];
                        return _buildHistoryCard(context, ref, history);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, WidgetRef ref, history) {
    return GestureDetector(
      onTap: () => _openHistoryEditor(context, ref, history),
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
  Future<void> _openHistoryEditor(BuildContext context, WidgetRef ref, history) async {
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
      if (context.mounted) {
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

    if (context.mounted) {
      ref.read(selectedLivePhotoIdsProvider.notifier).setIds(
            selectedAssets.map((a) => a.id).toList(),
          );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PuzzleEditorScreen(),
        ),
      );
    }
  }
}
