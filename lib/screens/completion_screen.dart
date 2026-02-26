import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 完成页面 - Live Photo 保存成功
class CompletionScreen extends StatelessWidget {
  final Uint8List? thumbnail; // 拼图缩略图
  final int photoCount; // 照片数量

  const CompletionScreen({
    super.key,
    this.thumbnail,
    required this.photoCount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F3),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close Button
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
                        Icons.close,
                        size: 18,
                        color: Color(0xFFFF4D80),
                      ),
                      onPressed: () {
                        // 返回首页，清空所有页面栈
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Success Animation / Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF85A2).withOpacity(0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 60,
                        color: Color(0xFF4CAF50),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Success Title
                    const Text(
                      '创作完成！',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF85A2),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Live Photo 已保存到相册',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Preview
                    if (thumbnail != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF85A2).withOpacity(0.4),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                                spreadRadius: -5,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: AspectRatio(
                              aspectRatio: 3 / 4,
                              child: Image.memory(
                                thumbnail!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 32),

                    // Stats
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat(Icons.photo_library, '$photoCount', '照片'),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey.shade200,
                          ),
                          _buildStat(Icons.play_circle, 'LIVE', '格式'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Bottom Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Share Button
                  _buildActionButton(
                    icon: Icons.share,
                    label: '分享',
                    color: const Color(0xFFFF85A2),
                    onTap: () => _shareImage(context),
                  ),
                  const SizedBox(height: 12),

                  // Create New Button
                  _buildActionButton(
                    icon: Icons.add_circle_outline,
                    label: '创建新拼图',
                    color: Colors.white,
                    textColor: const Color(0xFFFF85A2),
                    onTap: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFFFF85A2),
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    final isWhite = color == Colors.white;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          border: isWhite
              ? Border.all(color: const Color(0xFFFF85A2), width: 2)
              : null,
          boxShadow: [
            if (!isWhite)
              BoxShadow(
                color: const Color(0xFFFF85A2).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: textColor ?? Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor ?? Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareImage(BuildContext context) async {
    try {
      if (thumbnail == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法分享：缩略图不可用')),
        );
        return;
      }

      // 保存临时文件
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/live_puzzle_share.jpg');
      await file.writeAsBytes(thumbnail!);

      // 分享
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '我用 LivePuzzle 创建了一个 Live Photo 拼图！',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败：$e')),
        );
      }
    }
  }
}
