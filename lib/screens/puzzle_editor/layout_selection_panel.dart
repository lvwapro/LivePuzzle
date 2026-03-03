import 'package:flutter/material.dart';
import '../../models/canvas_config.dart';
import '../../models/layout_template.dart';
import '../../l10n/app_localizations.dart';

/// 布局类型标签
enum LayoutTabType {
  puzzle,    // 拼图
  longImage, // 长图拼接
}

/// 布局选择面板 - 新版本（数据驱动）
class LayoutSelectionPanel extends StatefulWidget {
  final int photoCount;
  final String? selectedLayoutId; // 当前选中的布局ID
  final String? selectedRatio; // 当前画布比例
  final Function(CanvasConfig canvas, LayoutTemplate template) onLayoutSelected;

  const LayoutSelectionPanel({
    super.key,
    required this.photoCount,
    this.selectedLayoutId,
    this.selectedRatio,
    required this.onLayoutSelected,
  });

  @override
  State<LayoutSelectionPanel> createState() => _LayoutSelectionPanelState();
}

class _LayoutSelectionPanelState extends State<LayoutSelectionPanel> {
  String _selectedRatio = '1:1';
  LayoutTabType _selectedTab = LayoutTabType.puzzle;
  String? _selectedLayoutId; // 当前选中的布局ID

  @override
  void initState() {
    super.initState();
    _selectedLayoutId = widget.selectedLayoutId;
    // 🔥 同步画布比例
    if (widget.selectedRatio != null) {
      _selectedRatio = widget.selectedRatio!;
    }
    // 🔥 根据初始布局ID自动切换到对应标签
    if (_selectedLayoutId != null) {
      if (_selectedLayoutId!.startsWith('long_')) {
        _selectedTab = LayoutTabType.longImage;
      } else {
        _selectedTab = LayoutTabType.puzzle;
      }
    }
  }

  @override
  void didUpdateWidget(LayoutSelectionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedLayoutId != oldWidget.selectedLayoutId) {
      _selectedLayoutId = widget.selectedLayoutId;
      // 🔥 根据新的布局ID自动切换标签
      if (_selectedLayoutId != null) {
        setState(() {
          if (_selectedLayoutId!.startsWith('long_')) {
            _selectedTab = LayoutTabType.longImage;
          } else {
            _selectedTab = LayoutTabType.puzzle;
          }
        });
      }
    }
    // 🔥 同步画布比例更新
    if (widget.selectedRatio != null && widget.selectedRatio != oldWidget.selectedRatio) {
      setState(() {
        _selectedRatio = widget.selectedRatio!;
      });
    }
  }

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
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标签栏
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTab(l10n.puzzleTab, LayoutTabType.puzzle),
                const SizedBox(width: 40),
                _buildTab(l10n.longImageTab, LayoutTabType.longImage),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade200),

          // 内容区域
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 长图拼接标签不显示画布比例
                  if (_selectedTab == LayoutTabType.puzzle) ...[
                    // 画布比例选择
                    Text(
                      l10n.canvasRatio,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
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
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? const Color(0xFFFF85A2)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFFF85A2)
                                        : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    ratio['label']!,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.grey.shade700,
                                      fontSize: 13,
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
                    const SizedBox(height: 10),
                  ],

                  // 布局模板选择
                  Text(
                    _selectedTab == LayoutTabType.longImage ? l10n.stitchDirection : l10n.layoutStyle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 布局网格
                  Builder(
                    builder: (context) {
                      final layouts = _getCurrentLayouts();
                      
                      if (layouts.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              '暂无适配的布局',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }
                      
                      // 长图拼接使用列表展示，拼图使用网格
                      if (_selectedTab == LayoutTabType.longImage) {
                        return Column(
                          children: layouts.map((layout) => 
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildLongImageLayoutItem(layout),
                            )
                          ).toList(),
                        );
                      }
                      
                      return GridView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
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
              color: isSelected ? Colors.black87 : Colors.grey.shade400,
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
    final isSelected = _selectedLayoutId == layout.id;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedLayoutId = layout.id);
        final canvas = _getCurrentCanvas();
        widget.onLayoutSelected(canvas, layout);
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEF6B8A) // 选中：深粉背景
              : const Color(0xFFFFF0F3), // 未选中：浅粉底色
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFEF6B8A).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: LayoutTemplatePainter(
                template: layout,
                color: isSelected
                    ? const Color(0xFFF9A0B5)
                    : const Color(0xFFFFB6C8),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 长图拼接布局项（横向显示）
  Widget _buildLongImageLayoutItem(LayoutTemplate layout) {
    final l10n = AppLocalizations.of(context)!;
    final isHorizontal = layout.id == 'long_horizontal';
    final isSelected = _selectedLayoutId == layout.id;
    
    return GestureDetector(
      onTap: () {
        setState(() => _selectedLayoutId = layout.id);
        final canvas = CanvasConfig.fromRatio('1:1');
        widget.onLayoutSelected(canvas, layout);
      },
      child: Container(
        height: 60,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFEF6B8A) // 选中：深粉背景
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFEF6B8A)
                : Colors.grey.shade200,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFEF6B8A).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // 图标
            Container(
              width: 48,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFF9A0B5) // 选中时浅一点
                    : const Color(0xFFFFE0E8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isHorizontal ? Icons.view_week : Icons.view_stream,
                color: isSelected
                    ? Colors.white
                    : const Color(0xFFFF85A2),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // 文字说明
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    layout.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade800,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isHorizontal 
                        ? l10n.horizontalStitchDesc(widget.photoCount)
                        : l10n.verticalStitchDesc(widget.photoCount),
                    style: TextStyle(
                      color: isSelected 
                          ? Colors.white.withOpacity(0.9)
                          : Colors.grey.shade500,
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
              color: Colors.grey.shade300,
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
    final padding = 4.0;
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
    int maxRows = 0;
    int maxCols = 0;
    for (final block in template.blocks) {
      if (block.row > maxRows) maxRows = block.row;
      if (block.col > maxCols) maxCols = block.col;
    }
    maxRows += 1;
    maxCols += 1;

    const spacing = 3.0;
    // 根据实际可用区域动态计算格子大小
    final cellWidth = (drawArea.width - spacing * (maxCols - 1)) / maxCols;
    final cellHeight = (drawArea.height - spacing * (maxRows - 1)) / maxRows;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final block in template.blocks) {
      final rect = Rect.fromLTWH(
        padding + block.col * (cellWidth + spacing),
        padding + block.row * (cellHeight + spacing),
        cellWidth,
        cellHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        fillPaint,
      );
    }
  }

  void _drawHierarchy(Canvas canvas, Size drawArea, double padding) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const spacing = 3.0;

    // 主图占 60%
    final mainRect = Rect.fromLTWH(
      padding,
      padding,
      drawArea.width,
      drawArea.height * 0.6 - spacing / 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(mainRect, const Radius.circular(3)),
      fillPaint,
    );

    // 小图横排
    final secondaryCount = template.blocks.length - 1;
    if (secondaryCount <= 0) return;
    final secondaryWidth = (drawArea.width - spacing * (secondaryCount - 1)) / secondaryCount;
    final secondaryTop = padding + drawArea.height * 0.6 + spacing / 2;
    final secondaryHeight = drawArea.height * 0.4 - spacing / 2;
    for (int i = 0; i < secondaryCount; i++) {
      final rect = Rect.fromLTWH(
        padding + i * (secondaryWidth + spacing),
        secondaryTop,
        secondaryWidth,
        secondaryHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
