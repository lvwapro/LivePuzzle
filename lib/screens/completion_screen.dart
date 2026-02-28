import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

/// 完成页面 - Live Photo 保存成功
class CompletionScreen extends StatelessWidget {
  final Uint8List? thumbnail; // 拼图缩略图
  final int photoCount; // 照片数量
  /// 保存的图片比例（宽/高），用于预览区按比例展示
  final double imageAspectRatio;

  const CompletionScreen({
    super.key,
    this.thumbnail,
    required this.photoCount,
    this.imageAspectRatio = 1.0,
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
                        // 返回编辑页
                        Navigator.pop(context);
                      },
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),

            // 整页可滚动：预览、标题与底部按钮分享为一体，随滚动上移
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 30),

                    // Preview - 最长边限制，按保存图片比例展示：横图限宽，竖图限高
                    if (thumbnail != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 60),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const double maxSide = 400.0;
                            final ratio = imageAspectRatio > 0 ? imageAspectRatio : 1.0;
                            double w;
                            double h;
                            if (ratio >= 1.0) {
                              w = maxSide.clamp(0.0, constraints.maxWidth);
                              h = w / ratio;
                            } else {
                              h = maxSide;
                              w = h * ratio;
                            }
                            return Container(
                              width: w,
                              height: h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
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
                                borderRadius: BorderRadius.circular(16),
                                child: Image.memory(
                                  thumbnail!,
                                  fit: BoxFit.cover,
                                  width: w,
                                  height: h,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 32),

                    // Success Title - 标题小一点
                    const Text(
                      '创作完成！',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF85A2),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Live Photo 已保存到相册',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 创作新拼图按钮 + 分享：作为一部分，随内容上移
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildActionButton(
                            label: '创建新拼图',
                            color: const Color(0xFFFF85A2),
                            onTap: () {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            },
                          ),
                          const SizedBox(height: 24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '分享到',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildSharePlatform(
                                    context,
                                    icon: Icons.photo_album,
                                    label: '闪传相册',
                                    onTap: () => _saveToAlbum(context),
                                  ),
                                  _buildSharePlatform(
                                    context,
                                    icon: Icons.wechat,
                                    label: '微信好友',
                                    color: const Color(0xFF1AAD19),
                                    onTap: () => _shareToWeChat(context),
                                  ),
                                  _buildSharePlatform(
                                    context,
                                    icon: Icons.circle,
                                    label: '朋友圈',
                                    color: const Color(0xFF1AAD19),
                                    onTap: () => _shareToMoments(context),
                                  ),
                                  _buildSharePlatform(
                                    context,
                                    icon: Icons.music_note,
                                    label: '抖音',
                                    color: Colors.black,
                                    onTap: () => _shareToDouyin(context),
                                  ),
                                  _buildSharePlatform(
                                    context,
                                    icon: Icons.book,
                                    label: '小红书',
                                    color: const Color(0xFFFF2442),
                                    onTap: () => _shareToXiaohongshu(context),
                                  ),
                                ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildSharePlatform(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (color ?? Colors.grey.shade400).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color ?? Colors.grey.shade600,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // 保存到相册
  Future<void> _saveToAlbum(BuildContext context) async {
    try {
      if (thumbnail != null) {
        await ImageGallerySaver.saveImage(thumbnail!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已保存到相册'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    }
  }

  // 通用分享方法 - 调起系统分享面板
  Future<void> _shareImage(BuildContext context, {String? text}) async {
    try {
      if (thumbnail != null) {
        // 保存图片到临时文件
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/live_puzzle_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(thumbnail!);
        
        // 调起系统分享面板
        final result = await Share.shareXFiles(
          [XFile(file.path)],
          text: text ?? '我用 LivePuzzle 创建了精美的 Live Photo 拼图！',
        );
        
        // 分享完成后删除临时文件
        if (result.status == ShareResultStatus.success || 
            result.status == ShareResultStatus.dismissed) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败：$e')),
        );
      }
    }
  }

  // 分享到微信
  Future<void> _shareToWeChat(BuildContext context) async {
    await _shareImage(context, text: '分享我的 Live Photo 拼图到微信');
  }

  // 分享到朋友圈
  Future<void> _shareToMoments(BuildContext context) async {
    await _shareImage(context, text: '分享我的 Live Photo 拼图到朋友圈');
  }

  // 分享到抖音
  Future<void> _shareToDouyin(BuildContext context) async {
    await _shareImage(context, text: '分享我的 Live Photo 拼图到抖音');
  }

  // 分享到小红书
  Future<void> _shareToXiaohongshu(BuildContext context) async {
    await _shareImage(context, text: '分享我的 Live Photo 拼图到小红书');
  }

  Widget _buildActionButton({
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
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor ?? Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
