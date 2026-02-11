# Live Puzzle 布局系统重构

## 📋 重构概述

按照提供的架构设计文档，将 Live Puzzle 编辑器的布局系统从硬编码方式重构为**数据驱动的布局引擎**。

---

## 🏗️ 新架构（4层设计）

### 1. 基础数据模型层

#### `lib/models/canvas_config.dart`
- **`CanvasConfig`**: 画布配置（宽度、高度、比例）
- **`CanvasRatioType`**: 预设比例类型枚举
- 支持从比例字符串创建（如 `CanvasConfig.fromRatio('3:4')`）
- 自动判断横版/竖版

#### `lib/models/layout_template.dart`
- **`LayoutTemplate`**: 布局模板（定义相对占比，不含像素值）
- **`LayoutTemplateType`**: 布局类型（网格/主次/分栏/自由）
- **`LayoutBlock`**: 布局块配置（行、列、权重、位置）
- 预设布局库：1-9张图片的多种布局组合

#### `lib/models/image_block.dart`
- **`ImageBlock`**: 图片块实例（使用相对坐标 0-1）
- **`ImageBlockAbsolute`**: 绝对坐标版本（用于渲染）
- 支持自动转换：相对坐标 ↔ 绝对像素

---

### 2. 布局计算引擎层

#### `lib/services/layout_engine.dart`
**核心算法**：根据画布配置、布局模板和图片列表，自动计算所有图片块位置

- **`calculateLayout()`**: 主入口，根据布局类型分发计算
- **网格型算法**: 均分行列，自动计算单元格尺寸
- **主次型算法**: 竖版上下分布，横版左右分布，自适应画布比例
- **边界处理**: `constrainBlock()` 限制图片块在画布内
- **变换更新**: `updateBlockTransform()` 支持单图编辑

---

### 3. UI组件层

#### `lib/screens/puzzle_editor/layout_selection_panel.dart`
- 画布比例选择（3:4、1:1、16:9、6:19等）
- 布局样式网格（根据图片数量动态显示适配布局）
- `LayoutTemplatePainter`: 自定义绘制器，预览布局网格

#### `lib/screens/puzzle_editor/data_driven_canvas.dart`
- **`DataDrivenCanvas`**: 新的数据驱动画布组件
- 支持全局缩放/平移（`InteractiveViewer`）
- 支持单图编辑（缩放/旋转/拖动）
- 按 `zIndex` 渲染图片层级

---

### 4. 编辑器集成层

#### `lib/screens/puzzle_editor_screen.dart`
主要变更：
- 添加新数据模型状态：`_canvasConfig`、`_imageBlocks`、`_selectedBlockId`
- 重写 `_applyLayout()` 方法，使用布局引擎计算
- 更新 `_buildNewCanvas()` 使用 `DataDrivenCanvas`
- 更新 `LayoutSelectionPanel` 回调参数

---

## ✨ 核心优势

### 1. **可扩展性**
- 新增画布比例：只需在 `CanvasConfig` 添加比例值
- 新增布局：只需在 `LayoutTemplate.presetLayouts` 添加模板
- **无需修改计算逻辑**

### 2. **适配性**
- 同一布局模板自动适配不同画布比例
- 竖版/横版自动切换排列方向（主次型）
- 使用相对坐标（0-1），适配任意分辨率

### 3. **一致性**
- 所有布局计算逻辑集中在 `LayoutEngine`
- 统一的数据流：`画布配置 → 布局模板 → 图片块列表`

---

## 📊 数据流程

```
用户选择画布比例（如 3:4）
  ↓
系统创建 CanvasConfig.fromRatio('3:4')
  ↓
用户选择图片数量（如 4 张）
  ↓
系统筛选适配布局 LayoutTemplate.getLayoutsForImageCount(4)
  ↓
用户选择布局模板（如 2x2 网格）
  ↓
布局引擎计算 LayoutEngine.calculateLayout()
  ↓
生成 ImageBlock 列表（相对坐标 0-1）
  ↓
DataDrivenCanvas 渲染（转换为绝对像素）
  ↓
用户编辑（全局/单图）
  ↓
更新 ImageBlock，画布重渲染
```

---

## 🔄 兼容性

- **保留旧系统**: `_imageTransforms`、`_useNewCanvas` 仍存在，确保平滑过渡
- **关键帧**: `_keyframes` 保留用于未来关键帧动画功能
- **视频选择**: 旧的 `VideoFrameSelectorWidget` 不受影响

---

## 🚀 使用示例

### 在编辑器中应用布局

```dart
// 1. 用户选择比例和布局
final canvas = CanvasConfig.fromRatio('3:4');
final template = LayoutTemplate.presetLayouts
    .firstWhere((t) => t.id == 'grid_2x2');

// 2. 应用布局
_applyLayout(canvas, template);

// 内部自动调用：
// _imageBlocks = LayoutEngine.calculateLayout(
//   canvas: canvas,
//   template: template,
//   images: [image1, image2, image3, image4],
// );
```

---

## 📝 待完成功能

1. **自由布局**: 用户拖动分割线实时更新布局
2. **关键帧动画**: 存储每个关键帧的 `ImageBlock` 状态
3. **动画插值**: 在关键帧之间平滑过渡
4. **导出渲染**: 按画布比例导出最终 Live Photo

---

## 🎯 测试建议

1. 选择不同数量的图片（1-9张）
2. 选择不同画布比例（3:4、1:1、16:9 等）
3. 应用不同布局模板
4. 验证图片是否正确排列
5. 尝试单图编辑（缩放/旋转/移动）
6. 验证图片块是否保持在画布内

---

## 📚 参考文档

原始设计文档要点：
- **相对值计算**: 所有坐标/尺寸先按相对画布的 0-1 值计算
- **布局缓存**: 常用比例+图片数量的布局计算结果可缓存
- **边界处理**: 图片块移动/缩放时限制在画布内
- **可扩展**: 新增比例/布局无需修改计算逻辑
