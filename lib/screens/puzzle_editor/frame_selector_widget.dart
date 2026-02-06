import 'dart:typed_data';
import 'package:flutter/material.dart';

/// 帧选择器组件 - 视频播放条样式
class FrameSelectorWidget extends StatelessWidget {
  static const int kTotalFrames = 16; // 🔥 总帧数
  
  final int selectedFrameIndex;
  final Uint8List? currentFrameImage;
  final bool isCover; // 🔥 当前帧是否是封面
  final Function(int) onFrameChanged;
  final VoidCallback onSetCover; // 🔥 设置为封面的回调

  const FrameSelectorWidget({
    super.key,
    required this.selectedFrameIndex,
    required this.currentFrameImage,
    required this.isCover,
    required this.onFrameChanged,
    required this.onSetCover,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 标题和封面标识
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '设为封面照片',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A3F44),
                ),
              ),
              if (isCover) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D7D),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '当前封面',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // 大图预览 - 实时显示当前帧
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
              border: isCover
                  ? Border.all(color: const Color(0xFFFF4D7D), width: 3)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: currentFrameImage != null
                  ? Image.memory(
                      currentFrameImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : const Center(
                      child: Icon(
                        Icons.image,
                        size: 64,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 20),

          // 🔥 设置为封面按钮
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onSetCover,
              style: ElevatedButton.styleFrom(
                backgroundColor: isCover 
                    ? Colors.grey.shade400 
                    : const Color(0xFFFF4D7D),
                foregroundColor: Colors.white,
                elevation: isCover ? 0 : 4,
                shadowColor: const Color(0xFFFF4D7D).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isCover ? Icons.check_circle : Icons.star,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCover ? '已设为封面' : '设置为封面',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 滑动选择器 - 类似视频播放条
          Column(
            children: [
              // 时间指示
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Frame ${selectedFrameIndex + 1} / $kTotalFrames',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4A3F44),
                      ),
                    ),
                    Text(
                      '${(selectedFrameIndex * 0.125).toStringAsFixed(2)}s', // 🔥 2秒/16帧 ≈ 0.125秒/帧
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 滑块 - 像视频播放条
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: const Color(0xFFFF4D7D),
                  inactiveTrackColor: Colors.grey.shade300,
                  thumbColor: Colors.white,
                  overlayColor: const Color(0xFFFF4D7D).withOpacity(0.2),
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 12,
                    elevation: 4,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 20,
                  ),
                ),
                child: Slider(
                  value: selectedFrameIndex.toDouble(),
                  min: 0,
                  max: (kTotalFrames - 1).toDouble(), // 🔥 最大值为15
                  divisions: kTotalFrames - 1, // 🔥 15个分割点
                  onChanged: (value) => onFrameChanged(value.toInt()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 进度指示器 - 简洁的点 (只显示关键帧)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(8, (index) {
              // 🔥 将16帧映射到8个点显示
              final frameStep = kTotalFrames ~/ 8; // 每2帧对应1个点
              final mappedFrame = index * frameStep;
              final isInRange = selectedFrameIndex >= mappedFrame && 
                               selectedFrameIndex < (mappedFrame + frameStep);
              
              return Container(
                width: isInRange ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isInRange
                      ? const Color(0xFFFF4D7D)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
