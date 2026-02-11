import 'package:flutter/material.dart';

/// 编辑状态枚举
enum EditorState {
  global,  // 全局编辑状态
  single,  // 单图编辑状态
}

/// 全局工具类型
enum GlobalTool {
  layout,    // 布局
  filter,    // 滤镜
  adjust,    // 调节
  text,      // 文字
}

/// 单图工具类型
enum SingleTool {
  filter,    // 滤镜
  adjust,    // 调节
  replace,   // 替换
  rotate,    // 旋转
  flipH,     // 水平翻转
  flipV,     // 垂直翻转
}

/// 动态工具栏 - 根据编辑状态显示不同工具
class DynamicToolbar extends StatelessWidget {
  final EditorState editorState;
  final GlobalTool? selectedGlobalTool;
  final SingleTool? selectedSingleTool;
  final Function(GlobalTool) onGlobalToolTap;
  final Function(SingleTool) onSingleToolTap;

  const DynamicToolbar({
    super.key,
    required this.editorState,
    this.selectedGlobalTool,
    this.selectedSingleTool,
    required this.onGlobalToolTap,
    required this.onSingleToolTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(editorState),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: editorState == EditorState.global
            ? _buildGlobalTools()
            : _buildSingleTools(),
      ),
    );
  }

  Widget _buildGlobalTools() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildToolButton(
          icon: Icons.dashboard_outlined,
          label: '布局',
          isSelected: selectedGlobalTool == GlobalTool.layout,
          onTap: () => onGlobalToolTap(GlobalTool.layout),
        ),
        _buildToolButton(
          icon: Icons.filter_vintage_outlined,
          label: '滤镜',
          isSelected: selectedGlobalTool == GlobalTool.filter,
          onTap: () => onGlobalToolTap(GlobalTool.filter),
        ),
        _buildToolButton(
          icon: Icons.tune_outlined,
          label: '调节',
          isSelected: selectedGlobalTool == GlobalTool.adjust,
          onTap: () => onGlobalToolTap(GlobalTool.adjust),
        ),
        _buildToolButton(
          icon: Icons.text_fields_outlined,
          label: '文字',
          isSelected: selectedGlobalTool == GlobalTool.text,
          onTap: () => onGlobalToolTap(GlobalTool.text),
        ),
      ],
    );
  }

  Widget _buildSingleTools() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildToolButton(
          icon: Icons.filter_vintage_outlined,
          label: '滤镜',
          isSelected: selectedSingleTool == SingleTool.filter,
          onTap: () => onSingleToolTap(SingleTool.filter),
        ),
        _buildToolButton(
          icon: Icons.tune_outlined,
          label: '调节',
          isSelected: selectedSingleTool == SingleTool.adjust,
          onTap: () => onSingleToolTap(SingleTool.adjust),
        ),
        _buildToolButton(
          icon: Icons.swap_horiz,
          label: '替换',
          isSelected: selectedSingleTool == SingleTool.replace,
          onTap: () => onSingleToolTap(SingleTool.replace),
        ),
        _buildToolButton(
          icon: Icons.rotate_90_degrees_ccw_outlined,
          label: '旋转',
          isSelected: selectedSingleTool == SingleTool.rotate,
          onTap: () => onSingleToolTap(SingleTool.rotate),
        ),
        _buildToolButton(
          icon: Icons.flip,
          label: '水平',
          isSelected: selectedSingleTool == SingleTool.flipH,
          onTap: () => onSingleToolTap(SingleTool.flipH),
        ),
        _buildToolButton(
          icon: Icons.flip,
          label: '垂直',
          isSelected: selectedSingleTool == SingleTool.flipV,
          onTap: () => onSingleToolTap(SingleTool.flipV),
          rotate: true,
        ),
      ],
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool rotate = false,
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
              color: isSelected
                  ? const Color(0xFFFF85A2).withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Transform.rotate(
              angle: rotate ? 1.5708 : 0, // 90度
              child: Icon(
                icon,
                color: isSelected
                    ? const Color(0xFFFF85A2)
                    : const Color(0xFF6B7280),
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? const Color(0xFFFF85A2)
                  : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}
