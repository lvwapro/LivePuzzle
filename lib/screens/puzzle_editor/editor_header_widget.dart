import 'package:flutter/material.dart';
import 'package:live_puzzle/l10n/app_localizations.dart';

/// 编辑器头部组件
class EditorHeaderWidget extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onDone;
  final VoidCallback? onPlayLive;  // 🔥 播放 Live 的回调
  final bool isPlayingLive;  // 🔥 是否正在播放

  const EditorHeaderWidget({
    super.key,
    required this.onBack,
    required this.onDone,
    this.onPlayLive,
    this.isPlayingLive = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFF85A1).withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back Button - 圆形白色背景样式（与选择页一致）
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
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                ),
              ),
              // Title / Live Play Button
              if (onPlayLive != null)
                GestureDetector(
                  onTap: onPlayLive,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPlayingLive ? Icons.pause : Icons.play_arrow,
                        size: 20,
                        color: const Color(0xFFFF4D7D),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPlayingLive ? l10n.playing : l10n.liveFormat,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF4D7D),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  l10n.livePuzzleTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF4D7D),
                    letterSpacing: -0.5,
                  ),
                ),
              // Done Button
              GestureDetector(
                onTap: onDone,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D7D),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4D7D).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    l10n.done,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
