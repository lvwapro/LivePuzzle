/// 布局模板类型
enum LayoutTemplateType {
  grid,        // 网格型（等分）
  hierarchy,   // 主次型（一大多小）
  column,      // 分栏型（先分栏再分格）
  free,        // 自由型（用户拖动）
  positioned,  // 自定义定位型（显式坐标）
}

/// 布局块配置
class LayoutBlock {
  final int row;            // 网格行（仅grid型）
  final int col;            // 网格列（仅grid型）
  final double weight;      // 占比权重（主次型/分栏型）
  final BlockPosition position; // 相对位置（仅主次型）
  // positioned 布局：显式相对坐标 (0-1)
  final double? relX;
  final double? relY;
  final double? relWidth;
  final double? relHeight;

  const LayoutBlock({
    this.row = 0,
    this.col = 0,
    this.weight = 1.0,
    this.position = BlockPosition.none,
    this.relX,
    this.relY,
    this.relWidth,
    this.relHeight,
  });
}

/// 块相对位置
enum BlockPosition {
  none,    // 无特殊位置
  top,     // 顶部
  left,    // 左侧
  bottom,  // 底部
  right,   // 右侧
  center,  // 中心
}

/// 布局模板（定义相对占比，不含具体像素）
class LayoutTemplate {
  final String id;                    // 布局ID（如 "grid_2x2" "hierarchy_1big_3small"）
  final LayoutTemplateType type;      // 布局类型
  final String name;                  // 显示名称
  final int imageCount;               // 适配的图片数量
  final List<LayoutBlock> blocks;     // 布局块列表

  const LayoutTemplate({
    required this.id,
    required this.type,
    required this.name,
    required this.imageCount,
    required this.blocks,
  });

  /// 预设布局库
  static List<LayoutTemplate> get presetLayouts => [
    // ========== 1张图片布局 ==========
    const LayoutTemplate(
      id: 'single',
      type: LayoutTemplateType.grid,
      name: '单图',
      imageCount: 1,
      blocks: [
        LayoutBlock(row: 0, col: 0, weight: 1.0),
      ],
    ),

    // ========== 2张图片布局 ==========
    const LayoutTemplate(
      id: 'grid_1x2',
      type: LayoutTemplateType.grid,
      name: '左右平分',
      imageCount: 2,
      blocks: [
        LayoutBlock(row: 0, col: 0),
        LayoutBlock(row: 0, col: 1),
      ],
    ),
    const LayoutTemplate(
      id: 'grid_2x1',
      type: LayoutTemplateType.grid,
      name: '上下平分',
      imageCount: 2,
      blocks: [
        LayoutBlock(row: 0, col: 0),
        LayoutBlock(row: 1, col: 0),
      ],
    ),
    const LayoutTemplate(
      id: 'hierarchy_1big_1small_vertical',
      type: LayoutTemplateType.hierarchy,
      name: '上大下小',
      imageCount: 2,
      blocks: [
        LayoutBlock(weight: 0.7, position: BlockPosition.top),
        LayoutBlock(weight: 0.3, position: BlockPosition.bottom),
      ],
    ),

    // ========== 3张图片布局 ==========
    const LayoutTemplate(
      id: 'grid_1x3',
      type: LayoutTemplateType.grid,
      name: '一行三列',
      imageCount: 3,
      blocks: [
        LayoutBlock(row: 0, col: 0),
        LayoutBlock(row: 0, col: 1),
        LayoutBlock(row: 0, col: 2),
      ],
    ),
    const LayoutTemplate(
      id: 'grid_3x1',
      type: LayoutTemplateType.grid,
      name: '三行一列',
      imageCount: 3,
      blocks: [
        LayoutBlock(row: 0, col: 0),
        LayoutBlock(row: 1, col: 0),
        LayoutBlock(row: 2, col: 0),
      ],
    ),
    const LayoutTemplate(
      id: 'hierarchy_1big_2small',
      type: LayoutTemplateType.hierarchy,
      name: '一大两小',
      imageCount: 3,
      blocks: [
        LayoutBlock(weight: 0.65, position: BlockPosition.top),
        LayoutBlock(weight: 0.35, position: BlockPosition.bottom),
        LayoutBlock(weight: 0.35, position: BlockPosition.bottom),
      ],
    ),

    // ========== 4张图片布局 ==========
    const LayoutTemplate(
      id: 'grid_2x2',
      type: LayoutTemplateType.grid,
      name: '2x2网格',
      imageCount: 4,
      blocks: [
        LayoutBlock(row: 0, col: 0),
        LayoutBlock(row: 0, col: 1),
        LayoutBlock(row: 1, col: 0),
        LayoutBlock(row: 1, col: 1),
      ],
    ),
    const LayoutTemplate(
      id: 'grid_1x4',
      type: LayoutTemplateType.grid,
      name: '一行四列',
      imageCount: 4,
      blocks: [
        LayoutBlock(row: 0, col: 0),
        LayoutBlock(row: 0, col: 1),
        LayoutBlock(row: 0, col: 2),
        LayoutBlock(row: 0, col: 3),
      ],
    ),
    const LayoutTemplate(
      id: 'grid_4x1',
      type: LayoutTemplateType.grid,
      name: '四行一列',
      imageCount: 4,
      blocks: [
        LayoutBlock(row: 0, col: 0),
        LayoutBlock(row: 1, col: 0),
        LayoutBlock(row: 2, col: 0),
        LayoutBlock(row: 3, col: 0),
      ],
    ),

    // ========== 6张图片布局 ==========
    const LayoutTemplate(
      id: 'grid_2x3',
      type: LayoutTemplateType.grid,
      name: '2x3网格',
      imageCount: 6,
      blocks: [
        LayoutBlock(row: 0, col: 0),
        LayoutBlock(row: 0, col: 1),
        LayoutBlock(row: 0, col: 2),
        LayoutBlock(row: 1, col: 0),
        LayoutBlock(row: 1, col: 1),
        LayoutBlock(row: 1, col: 2),
      ],
    ),
    const LayoutTemplate(
      id: 'grid_3x2',
      type: LayoutTemplateType.grid,
      name: '3x2网格',
      imageCount: 6,
      blocks: [
        LayoutBlock(row: 0, col: 0),
        LayoutBlock(row: 0, col: 1),
        LayoutBlock(row: 1, col: 0),
        LayoutBlock(row: 1, col: 1),
        LayoutBlock(row: 2, col: 0),
        LayoutBlock(row: 2, col: 1),
      ],
    ),

    // ========== 3张 positioned ==========
    const LayoutTemplate(
      id: 'pos_3_left_2right',
      type: LayoutTemplateType.positioned,
      name: '左大右二',
      imageCount: 3,
      blocks: [
        LayoutBlock(relX: 0, relY: 0, relWidth: 0.6, relHeight: 1.0),
        LayoutBlock(relX: 0.6, relY: 0, relWidth: 0.4, relHeight: 0.5),
        LayoutBlock(relX: 0.6, relY: 0.5, relWidth: 0.4, relHeight: 0.5),
      ],
    ),

    // ========== 4张 positioned ==========
    const LayoutTemplate(
      id: 'pos_4_1left_3right',
      type: LayoutTemplateType.positioned,
      name: '左大右三',
      imageCount: 4,
      blocks: [
        LayoutBlock(relX: 0, relY: 0, relWidth: 0.6, relHeight: 1.0),
        LayoutBlock(relX: 0.6, relY: 0, relWidth: 0.4, relHeight: 1 / 3),
        LayoutBlock(relX: 0.6, relY: 1 / 3, relWidth: 0.4, relHeight: 1 / 3),
        LayoutBlock(relX: 0.6, relY: 2 / 3, relWidth: 0.4, relHeight: 1 / 3),
      ],
    ),
    const LayoutTemplate(
      id: 'pos_4_1top_3bottom',
      type: LayoutTemplateType.positioned,
      name: '上大下三',
      imageCount: 4,
      blocks: [
        LayoutBlock(relX: 0, relY: 0, relWidth: 1.0, relHeight: 0.6),
        LayoutBlock(relX: 0, relY: 0.6, relWidth: 1 / 3, relHeight: 0.4),
        LayoutBlock(relX: 1 / 3, relY: 0.6, relWidth: 1 / 3, relHeight: 0.4),
        LayoutBlock(relX: 2 / 3, relY: 0.6, relWidth: 1 / 3, relHeight: 0.4),
      ],
    ),

    // ========== 5张图片布局 ==========
    const LayoutTemplate(
      id: 'pos_5_2top_3bottom',
      type: LayoutTemplateType.positioned,
      name: '上二下三',
      imageCount: 5,
      blocks: [
        LayoutBlock(relX: 0, relY: 0, relWidth: 0.5, relHeight: 0.5),
        LayoutBlock(relX: 0.5, relY: 0, relWidth: 0.5, relHeight: 0.5),
        LayoutBlock(relX: 0, relY: 0.5, relWidth: 1 / 3, relHeight: 0.5),
        LayoutBlock(relX: 1 / 3, relY: 0.5, relWidth: 1 / 3, relHeight: 0.5),
        LayoutBlock(relX: 2 / 3, relY: 0.5, relWidth: 1 / 3, relHeight: 0.5),
      ],
    ),
    const LayoutTemplate(
      id: 'pos_5_3top_2bottom',
      type: LayoutTemplateType.positioned,
      name: '上三下二',
      imageCount: 5,
      blocks: [
        LayoutBlock(relX: 0, relY: 0, relWidth: 1 / 3, relHeight: 0.5),
        LayoutBlock(relX: 1 / 3, relY: 0, relWidth: 1 / 3, relHeight: 0.5),
        LayoutBlock(relX: 2 / 3, relY: 0, relWidth: 1 / 3, relHeight: 0.5),
        LayoutBlock(relX: 0, relY: 0.5, relWidth: 0.5, relHeight: 0.5),
        LayoutBlock(relX: 0.5, relY: 0.5, relWidth: 0.5, relHeight: 0.5),
      ],
    ),
    const LayoutTemplate(
      id: 'pos_5_1big_4small',
      type: LayoutTemplateType.positioned,
      name: '一大四小',
      imageCount: 5,
      blocks: [
        LayoutBlock(relX: 0, relY: 0, relWidth: 0.6, relHeight: 1.0),
        LayoutBlock(relX: 0.6, relY: 0, relWidth: 0.4, relHeight: 0.25),
        LayoutBlock(relX: 0.6, relY: 0.25, relWidth: 0.4, relHeight: 0.25),
        LayoutBlock(relX: 0.6, relY: 0.5, relWidth: 0.4, relHeight: 0.25),
        LayoutBlock(relX: 0.6, relY: 0.75, relWidth: 0.4, relHeight: 0.25),
      ],
    ),
    const LayoutTemplate(
      id: 'grid_1x5',
      type: LayoutTemplateType.grid,
      name: '一行五列',
      imageCount: 5,
      blocks: [
        LayoutBlock(row: 0, col: 0),
        LayoutBlock(row: 0, col: 1),
        LayoutBlock(row: 0, col: 2),
        LayoutBlock(row: 0, col: 3),
        LayoutBlock(row: 0, col: 4),
      ],
    ),
    const LayoutTemplate(
      id: 'grid_5x1',
      type: LayoutTemplateType.grid,
      name: '五行一列',
      imageCount: 5,
      blocks: [
        LayoutBlock(row: 0, col: 0),
        LayoutBlock(row: 1, col: 0),
        LayoutBlock(row: 2, col: 0),
        LayoutBlock(row: 3, col: 0),
        LayoutBlock(row: 4, col: 0),
      ],
    ),

    // ========== 7张图片布局 ==========
    const LayoutTemplate(
      id: 'pos_7_3top_4bottom',
      type: LayoutTemplateType.positioned,
      name: '上三下四',
      imageCount: 7,
      blocks: [
        LayoutBlock(relX: 0, relY: 0, relWidth: 1 / 3, relHeight: 0.5),
        LayoutBlock(relX: 1 / 3, relY: 0, relWidth: 1 / 3, relHeight: 0.5),
        LayoutBlock(relX: 2 / 3, relY: 0, relWidth: 1 / 3, relHeight: 0.5),
        LayoutBlock(relX: 0, relY: 0.5, relWidth: 0.25, relHeight: 0.5),
        LayoutBlock(relX: 0.25, relY: 0.5, relWidth: 0.25, relHeight: 0.5),
        LayoutBlock(relX: 0.5, relY: 0.5, relWidth: 0.25, relHeight: 0.5),
        LayoutBlock(relX: 0.75, relY: 0.5, relWidth: 0.25, relHeight: 0.5),
      ],
    ),
    const LayoutTemplate(
      id: 'pos_7_4top_3bottom',
      type: LayoutTemplateType.positioned,
      name: '上四下三',
      imageCount: 7,
      blocks: [
        LayoutBlock(relX: 0, relY: 0, relWidth: 0.25, relHeight: 0.5),
        LayoutBlock(relX: 0.25, relY: 0, relWidth: 0.25, relHeight: 0.5),
        LayoutBlock(relX: 0.5, relY: 0, relWidth: 0.25, relHeight: 0.5),
        LayoutBlock(relX: 0.75, relY: 0, relWidth: 0.25, relHeight: 0.5),
        LayoutBlock(relX: 0, relY: 0.5, relWidth: 1 / 3, relHeight: 0.5),
        LayoutBlock(relX: 1 / 3, relY: 0.5, relWidth: 1 / 3, relHeight: 0.5),
        LayoutBlock(relX: 2 / 3, relY: 0.5, relWidth: 1 / 3, relHeight: 0.5),
      ],
    ),

    // ========== 8张图片布局 ==========
    const LayoutTemplate(
      id: 'grid_4x2',
      type: LayoutTemplateType.grid,
      name: '4x2网格',
      imageCount: 8,
      blocks: [
        LayoutBlock(row: 0, col: 0), LayoutBlock(row: 0, col: 1),
        LayoutBlock(row: 0, col: 2), LayoutBlock(row: 0, col: 3),
        LayoutBlock(row: 1, col: 0), LayoutBlock(row: 1, col: 1),
        LayoutBlock(row: 1, col: 2), LayoutBlock(row: 1, col: 3),
      ],
    ),
    const LayoutTemplate(
      id: 'grid_2x4',
      type: LayoutTemplateType.grid,
      name: '2x4网格',
      imageCount: 8,
      blocks: [
        LayoutBlock(row: 0, col: 0), LayoutBlock(row: 0, col: 1),
        LayoutBlock(row: 1, col: 0), LayoutBlock(row: 1, col: 1),
        LayoutBlock(row: 2, col: 0), LayoutBlock(row: 2, col: 1),
        LayoutBlock(row: 3, col: 0), LayoutBlock(row: 3, col: 1),
      ],
    ),

    // ========== 9张图片布局 ==========
    const LayoutTemplate(
      id: 'grid_3x3',
      type: LayoutTemplateType.grid,
      name: '3x3网格',
      imageCount: 9,
      blocks: [
        LayoutBlock(row: 0, col: 0),
        LayoutBlock(row: 0, col: 1),
        LayoutBlock(row: 0, col: 2),
        LayoutBlock(row: 1, col: 0),
        LayoutBlock(row: 1, col: 1),
        LayoutBlock(row: 1, col: 2),
        LayoutBlock(row: 2, col: 0),
        LayoutBlock(row: 2, col: 1),
        LayoutBlock(row: 2, col: 2),
      ],
    ),
  ];

  /// 根据图片数量筛选适配的布局
  static List<LayoutTemplate> getLayoutsForImageCount(int count) {
    return presetLayouts.where((layout) => layout.imageCount == count).toList();
  }
  
  /// 🔥 获取长图拼接布局（支持任意数量）
  static List<LayoutTemplate> getLongImageLayouts(int count) {
    return [
      // 横向长图拼接
      LayoutTemplate(
        id: 'long_horizontal',
        type: LayoutTemplateType.grid,
        name: '横向拼接',
        imageCount: count,
        blocks: List.generate(
          count,
          (i) => LayoutBlock(row: 0, col: i),
        ),
      ),
      // 纵向长图拼接
      LayoutTemplate(
        id: 'long_vertical',
        type: LayoutTemplateType.grid,
        name: '纵向拼接',
        imageCount: count,
        blocks: List.generate(
          count,
          (i) => LayoutBlock(row: i, col: 0),
        ),
      ),
    ];
  }
}
