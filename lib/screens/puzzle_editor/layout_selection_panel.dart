import 'package:flutter/material.dart';
import '../../models/canvas_config.dart';
import '../../models/layout_template.dart';

/// 布局类型标签
enum LayoutTabType {
  puzzle,    // 拼图
  longImage, // 长图拼接
}

/// 布局选择面板 - 新版本（数据驱动）
class LayoutSelectionPanel extends StatefulWidget {
  final int photoCount;
  final Function(CanvasConfig canvas, LayoutTemplate template) onLayoutSelected;

  const LayoutSelectionPanel({
    super.key,
    required this.photoCount,
    required this.onLayoutSelected,
  });

  @override
  State<LayoutSelectionPanel> createState() => _LayoutSelectionPanelState();
}

class _LayoutSelectionPanelState extends State<LayoutSelectionPanel> {
  String _selectedRatio = '1:1'; // 默认选择 1:1
  LayoutTabType _selectedTab = LayoutTabType.puzzle; // 默认拼图标签

  // 画布比例选项
  final List<Map<String, String>> _ratios = const [
    {'label': '3:4', 'ratio': '3:4'},
    {'label': '1:1', 'ratio': '1:1'},
    {'label': '9:16', 'ratio': '9:16'},
    {'label': '4:3', 'ratio': '4:3'},
    {'label': '16:9', 'ratio': '16:9'},
    {'label': '6:19', 'ratio': '6:19'},
  ];

  /// 获取当前选择的画布配置
  CanvasConfig _getCurrentCanvas() {
    return CanvasConfig.fromRatio(_selectedRatio);
  }

  /// 根据当前标签和图片数量获取布局模板
  List<LayoutTemplate> _getCurrentLayouts() {
    switch (_selectedTab) {
      case LayoutTabType.puzzle:
        return LayoutTemplate.getLayoutsForImageCount(widget.photoCount);
      case LayoutTabType.longImage:
        return LayoutTemplate.getLongImageLayouts(widget.photoCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280, // 🔥 从400降到280
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标签栏
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8), // 🔥 从12降到8
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTab('拼图', LayoutTabType.puzzle),
                const SizedBox(width: 40),
                _buildTab('长图拼接', LayoutTabType.longImage),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF2C2C2E)),

          // 内容区域
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12), // 🔥 从16降到12
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔥 长图拼接标签不显示画布比例（自动适应）
                  if (_selectedTab == LayoutTabType.puzzle) ...[
                    // 画布比例选择
                    const Text(
                      '画布比例',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12, // 🔥 从13降到12
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8), // 🔥 从12降到8
                    SizedBox(
                      height: 36, // 🔥 从40降到36
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _ratios.length,
                        itemBuilder: (context, index) {
                          final ratio = _ratios[index];
                          final isSelected = _selectedRatio == ratio['ratio'];
                          
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedRatio = ratio['ratio']!;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // 🔥 缩小内边距
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? const Color(0xFFFF85A2)
                                      : const Color(0xFF2C2C2E),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFFF85A2)
                                        : Colors.white.withOpacity(0.1),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    ratio['label']!,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                                      fontSize: 13, // 🔥 从14降到13
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16), // 🔥 从24降到16
                  ],

                  // 布局模板选择
                  Text(
                    _selectedTab == LayoutTabType.longImage ? '拼接方向' : '布局样式',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12, // 🔥 从13降到12
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8), // 🔥 从12降到8

                  // 布局网格
                  Builder(
                    builder: (context) {
                      final layouts = _getCurrentLayouts();
                      
                      if (layouts.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              '暂无适配的布局',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }
                      
                      // 🔥 长图拼接使用列表展示，拼图使用网格
                      if (_selectedTab == LayoutTabType.longImage) {
                        return Column(
                          children: layouts.map((layout) => 
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8), // 🔥 从12降到8
                              child: _buildLongImageLayoutItem(layout),
                            )
                          ).toList(),
                        );
                      }
                      
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4, // 🔥 从3增加到4，显示更多
                          mainAxisSpacing: 12, // 🔥 从16降到12
                          crossAxisSpacing: 12, // 🔥 从16降到12
                          childAspectRatio: 1.0,
                        ),
                        itemCount: layouts.length,
                        itemBuilder: (context, index) {
                          final layout = layouts[index];
                          return _buildLayoutItem(layout);
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, LayoutTabType type) {
    final isSelected = _selectedTab == type;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = type;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(
              width: 24,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFFFF85A2),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLayoutItem(LayoutTemplate layout) {
    return GestureDetector(
      onTap: () {
        final canvas = _getCurrentCanvas();
        widget.onLayoutSelected(canvas, layout);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: CustomPaint(
                painter: LayoutTemplatePainter(
                  template: layout,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                layout.name,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔥 长图拼接布局项（横向显示）
  Widget _buildLongImageLayoutItem(LayoutTemplate layout) {
    final isHorizontal = layout.id == 'long_horizontal';
    
    return GestureDetector(
      onTap: () {
        // 长图拼接自动使用1:1比例，由引擎自动计算实际画布尺寸
        final canvas = CanvasConfig.fromRatio('1:1');
        widget.onLayoutSelected(canvas, layout);
      },
      child: Container(
        height: 60, // 🔥 从80降到60
        padding: const EdgeInsets.all(12), // 🔥 从16降到12
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            // 图标
            Container(
              width: 48, // 🔥 从60降到48
              height: 36, // 🔥 从48降到36
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isHorizontal ? Icons.view_week : Icons.view_stream,
                color: const Color(0xFFFF85A2),
                size: 24, // 🔥 从32降到24
              ),
            ),
            const SizedBox(width: 12), // 🔥 从16降到12
            // 文字说明
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    layout.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 🔥 去掉 SizedBox 避免溢出
                  Text(
                    isHorizontal 
                        ? '${widget.photoCount}张图片从左到右拼接'
                        : '${widget.photoCount}张图片从上到下拼接',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.3),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

/// 布局模板绘制器（基于LayoutTemplate绘制预览）
class LayoutTemplatePainter extends CustomPainter {
  final LayoutTemplate template;
  final Color color;

  LayoutTemplatePainter({
    required this.template,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 8.0;
    final drawArea = Size(size.width - padding * 2, size.height - padding * 2);

    switch (template.type) {
      case LayoutTemplateType.grid:
        _drawGrid(canvas, drawArea, padding);
        break;
      case LayoutTemplateType.hierarchy:
        _drawHierarchy(canvas, drawArea, padding);
        break;
      default:
        _drawGrid(canvas, drawArea, padding);
    }
  }

  void _drawGrid(Canvas canvas, Size drawArea, double padding) {
    // 计算行列数
    int maxRows = 0;
    int maxCols = 0;
    for (final block in template.blocks) {
      if (block.row > maxRows) maxRows = block.row;
      if (block.col > maxCols) maxCols = block.col;
    }
    maxRows += 1;
    maxCols += 1;

    const cellWidth = 60.0;  // 固定单元格宽度
    const cellHeight = 60.0; // 固定单元格高度
    const spacing = 4.0;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 绘制网格块
    for (final block in template.blocks) {
      final rect = Rect.fromLTWH(
        padding + block.col * (cellWidth + spacing),
        padding + block.row * (cellHeight + spacing),
        cellWidth - spacing,
        cellHeight - spacing,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        fillPaint,
      );
    }
  }

  void _drawHierarchy(Canvas canvas, Size drawArea, double padding) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 简化绘制：主图占70%，小图占30%
    final mainRect = Rect.fromLTWH(
      padding + 4,
      padding + 4,
      drawArea.width - 8,
      drawArea.height * 0.65 - 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(mainRect, const Radius.circular(4)),
      fillPaint,
    );

    // 小图
    final secondaryCount = template.blocks.length - 1;
    final secondaryWidth = (drawArea.width - 8 - (secondaryCount - 1) * 4) / secondaryCount;
    for (int i = 0; i < secondaryCount; i++) {
      final rect = Rect.fromLTWH(
        padding + 4 + i * (secondaryWidth + 4),
        padding + drawArea.height * 0.65 + 4,
        secondaryWidth,
        drawArea.height * 0.35 - 8,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
