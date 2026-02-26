import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_puzzle/providers/puzzle_history_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 设置页面
class SettingsScreen extends ConsumerWidget {
  final bool showBackButton;
  
  const SettingsScreen({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  // Back Button - 可选
                  if (showBackButton)
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
                  if (showBackButton) const SizedBox(width: 16),
                  // Title
                  const Text(
                    '设置',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 通用设置
                    _buildSectionTitle('通用'),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      context,
                      icon: Icons.photo_library,
                      title: '照片质量',
                      subtitle: '高质量 (2000x2000)',
                      onTap: () {
                        // TODO: 显示质量选择对话框
                        _showQualityDialog(context);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      context,
                      icon: Icons.language,
                      title: '语言',
                      subtitle: '简体中文',
                      onTap: () {
                        // TODO: 显示语言选择对话框
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('语言设置功能开发中')),
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // 存储管理
                    _buildSectionTitle('存储'),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      context,
                      icon: Icons.history,
                      title: '清除历史记录',
                      subtitle: '删除所有历史记录',
                      trailing: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
                      onTap: () => _showClearHistoryDialog(context, ref),
                    ),

                    const SizedBox(height: 32),

                    // 关于
                    _buildSectionTitle('关于'),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      context,
                      icon: Icons.info_outline,
                      title: '版本信息',
                      subtitle: 'v1.0.0',
                      onTap: () {
                        _showAboutDialog(context);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      context,
                      icon: Icons.share,
                      title: '分享应用',
                      subtitle: '推荐给朋友',
                      onTap: () {
                        Share.share('我发现了一个超棒的 Live Photo 拼图应用！快来试试 LivePuzzle 吧！');
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      context,
                      icon: Icons.favorite,
                      title: '给我们评分',
                      subtitle: '在 App Store 评分',
                      onTap: () {
                        // TODO: 打开 App Store 评分页面
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('感谢您的支持！')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9CA3AF),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE0E8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFFF85A2),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFFFF85A2),
                  size: 16,
                ),
          ],
        ),
      ),
    );
  }

  void _showQualityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '照片质量',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildQualityOption('高质量 (2000x2000)', true),
            _buildQualityOption('中等质量 (1200x1200)', false),
            _buildQualityOption('节省空间 (800x800)', false),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '取消',
              style: TextStyle(color: Color(0xFFFF85A2)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('设置已保存')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF85A2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityOption(String label, bool selected) {
    return ListTile(
      title: Text(label),
      leading: Radio<bool>(
        value: true,
        groupValue: selected,
        onChanged: (value) {},
        activeColor: const Color(0xFFFF85A2),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  void _showClearHistoryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '清除历史记录',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        content: const Text('确定要删除所有历史记录吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '取消',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(puzzleHistoryProvider.notifier).clearAll();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('历史记录已清除'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('确定删除'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'LivePuzzle',
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontWeight: FontWeight.w700,
            color: Color(0xFFFF85A2),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '版本：v1.0.0',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '一个简单而有趣的 Live Photo 拼图应用',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '© 2024 LivePuzzle\n保留所有权利',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '关闭',
              style: TextStyle(color: Color(0xFFFF85A2)),
            ),
          ),
        ],
      ),
    );
  }
}
