import 'package:flutter/material.dart';

/// 导出进度对话框 - 使用 ValueNotifier 避免闪烁
class ExportProgressDialog extends StatefulWidget {
  const ExportProgressDialog({super.key});

  @override
  State<ExportProgressDialog> createState() => _ExportProgressDialogState();

  /// 显示进度对话框并返回控制器
  static ExportProgressController show(BuildContext context) {
    final controller = ExportProgressController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ExportProgressDialogContent(controller: controller),
    );
    
    return controller;
  }
}

class _ExportProgressDialogState extends State<ExportProgressDialog> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// 进度控制器
class ExportProgressController {
  final ValueNotifier<double> _progress = ValueNotifier(0.0);
  final ValueNotifier<String> _message = ValueNotifier('');
  final ValueNotifier<String?> _subMessage = ValueNotifier(null);
  
  ValueNotifier<double> get progress => _progress;
  ValueNotifier<String> get message => _message;
  ValueNotifier<String?> get subMessage => _subMessage;

  /// 更新进度
  void update({
    required double progress,
    required String message,
    String? subMessage,
  }) {
    _progress.value = progress;
    _message.value = message;
    _subMessage.value = subMessage;
  }

  /// 释放资源
  void dispose() {
    _progress.dispose();
    _message.dispose();
    _subMessage.dispose();
  }
}

/// 对话框内容
class _ExportProgressDialogContent extends StatelessWidget {
  final ExportProgressController controller;

  const _ExportProgressDialogContent({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 主标题
              ValueListenableBuilder<String>(
                valueListenable: controller.message,
                builder: (context, message, child) {
                  return Text(
                    message,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              
              const SizedBox(height: 16),

              // 进度条和百分比
              ValueListenableBuilder<double>(
                valueListenable: controller.progress,
                builder: (context, progress, child) {
                  return Column(
                    children: [
                      // 进度条
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 6,
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: const Color(0xFFFFE0E8),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF85A2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 百分比
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF85A2),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

