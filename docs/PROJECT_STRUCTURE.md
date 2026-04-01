# LivePuzzle 项目结构与技术文档

> 最后更新：2026-04-01
> 代码量：Dart ~11,882 行 | Swift ~1,911 行 | 总计 ~13,793 行

---

## 一、项目概述

LivePuzzle 是一款 iOS Live Photo 拼图创作工具，用户可以：
1. 从相册选取多张 Live Photo / 静态图
2. 在可视化画布编辑器中自由编排布局、调整裁剪和缩放
3. 为每张图设置自定义封面帧（视频帧选择）
4. 一键硬件加速合成导出为完整的 Live Photo（含配对视频 + 封面图）保存到相册

核心技术栈：**Flutter + Riverpod + MethodChannel + Swift（AVFoundation / Photos）**

---

## 二、架构分层

```
┌──────────────────────────────────────────────┐
│  UI 层   lib/screens/  lib/screens/*/        │  Widget 树 + 用户交互
├──────────────────────────────────────────────┤
│  状态层  lib/providers/                       │  Riverpod StateNotifier
├──────────────────────────────────────────────┤
│  业务层  lib/services/  lib/models/           │  布局引擎 + 媒体管理
├──────────────────────────────────────────────┤
│  桥接层  plugins/live_photo_bridge/lib/       │  Dart MethodChannel 封装
├──────────────────────────────────────────────┤
│  原生层  plugins/.../ios/Classes/             │  Swift 插件实现
└──────────────────────────────────────────────┘
```

**依赖方向严格单向**：UI → 状态 → 业务 → 桥接 → 原生，禁止逆向导入。

---

## 三、目录结构

### 3.1 Flutter 侧 (`lib/`)

```
lib/
├── main.dart                                    (183)  应用入口 + MaterialApp
├── l10n/                                               国际化
│   ├── app_localizations.dart                  (1135)  生成的本地化委托
│   ├── app_localizations_en.dart                (542)  英文翻译
│   ├── app_localizations_zh.dart                (537)  中文翻译
│   ├── app_en.arb                               (786)  英文 ARB 源
│   ├── app_zh.arb                               (198)  中文 ARB 源
│   └── album_name_localization.dart              (53)  系统相册名翻译
├── models/                                             数据模型
│   ├── image_block.dart                         (118)  ★ 核心块模型（相对坐标 0-1）
│   ├── canvas_config.dart                        (91)  画布尺寸/比例配置
│   ├── layout_template.dart                     (250)  布局模板定义 + 预设库
│   └── puzzle_history.dart                       (85)  历史记录序列化模型
├── providers/                                          状态管理
│   ├── locale_provider.dart                      (52)  语言切换 + 持久化
│   ├── photo_provider.dart                      (211)  ★ 照片列表/筛选/分页
│   └── puzzle_history_provider.dart              (82)  历史记录 CRUD
├── services/                                           业务逻辑
│   ├── layout_engine.dart                       (239)  ★ 布局计算引擎
│   └── live_photo_manager.dart                  (383)  ★ 相册管理 + Live Photo 识别
├── utils/                                              工具
│   ├── file_helpers.dart                         (65)  临时文件/缓存工具
│   └── permissions.dart                          (84)  权限请求封装
└── screens/                                            页面
    ├── main_screen.dart                          (90)  底部导航壳（首页 + 设置）
    ├── home_screen.dart                         (452)  ★ 首页（创建入口 + 历史）
    ├── photo_selection_screen.dart               (523)  ★ 照片选择页
    ├── puzzle_editor_screen.dart                 (448)  ★ 编辑器主页（part 分拆）
    ├── completion_screen.dart                   (383)  导出完成页
    ├── settings_screen.dart                     (484)  设置页
    ├── all_history_screen.dart                  (238)  全部历史列表
    ├── home/
    │   └── home_history_card.dart                (135)  历史卡片组件
    ├── photo_selection/
    │   ├── fullscreen_gallery.dart               (275)  全屏大图浏览
    │   ├── photo_grid_item.dart                  (152)  照片网格项
    │   ├── photo_thumbnail_widget.dart            (75)  缩略图组件
    │   ├── live_photo_preview_dialog.dart          (68)  Live Photo 预览弹窗
    │   └── selection_tab_widget.dart              (101)  筛选标签 + 相册选择
    └── puzzle_editor/
        ├── data_driven_canvas.dart               (455)  ★ 交互式拼图画布
        ├── layout_selection_panel.dart            (456)  布局模板选择面板
        ├── editor_export_logic.dart               (492)  ★ 导出逻辑（part）
        ├── editor_playback_logic.dart             (196)  播放预览逻辑（part）
        ├── editor_cover_logic.dart                (219)  封面帧设置（part）
        ├── editor_layout_logic.dart               (215)  布局切换逻辑（part）
        ├── editor_session_load.dart               (180)  会话加载（part）
        ├── video_frame_selector_widget.dart       (288)  视频帧滑动选择器
        ├── dynamic_toolbar.dart                   (192)  动态工具栏
        ├── editor_header_widget.dart              (136)  编辑器头部
        ├── canvas_shared_edge.dart                (151)  共享边拖拽算法
        ├── canvas_image_block_widget.dart          (169)  画布图片块渲染
        ├── canvas_edge_dividers.dart               (112)  分割线渲染
        └── layout_template_painter.dart            (103)  模板缩略图绘制
```

### 3.2 原生插件侧 (`plugins/live_photo_bridge/`)

```
plugins/live_photo_bridge/
├── lib/
│   └── live_photo_bridge.dart                    (72)  ★ Dart 桥接 API
└── ios/Classes/
    ├── LivePhotoBridgePlugin.swift               (433)  ★ 插件入口 + 软件合成
    ├── LivePhotoAssetService.swift               (258)  PHAsset 操作扩展
    ├── LivePhotoHardwareExport.swift             (478)  ★ 硬件加速导出扩展
    ├── HardwareVideoCompositor.swift             (499)  ★ 视频合成器核心
    └── BlockVideoCompositor.swift                (171)  自定义 AVVideoCompositing
```

---

## 四、核心数据流

### 4.1 主用户流程

```
首页 HomeScreen
  │
  ├─ [新建] → PhotoSelectionScreen（选择 2-9 张照片）
  │              │
  │              └─→ PuzzleEditorScreen（编辑器）
  │                      │
  │                      ├─ 选择画布比例（CanvasConfig）
  │                      ├─ 选择/切换布局模板（LayoutTemplate）
  │                      ├─ 交互画布调整（DataDrivenCanvas）
  │                      │    ├─ 拖拽平移/缩放图片
  │                      │    ├─ 拖拽共享边调整分割比例
  │                      │    └─ 长按交换图片位置
  │                      ├─ 设置封面帧（VideoFrameSelector）
  │                      ├─ 预览播放
  │                      └─ [导出] → 硬件加速合成 → CompletionScreen
  │
  └─ [历史] → 恢复编辑 → PuzzleEditorScreen
```

### 4.2 导出数据流（关键路径）

```
Flutter UI
  │  savePuzzleToGallery()
  │  构建 layoutConfig: { canvasWidth, canvasHeight, blocks[], isLongImage }
  │  构建 coverTimes: [每张图的封面时间 ms]
  ▼
LivePhotoBridge.createLivePhotoHardware(assetIds, layoutConfig, coverTimes)
  │  MethodChannel → "createLivePhotoHardware"
  ▼
Swift: LivePhotoHardwareExport.createLivePhotoHardware()
  │
  ├─ 解析 layoutConfig → CompositorConfig
  ├─ fetchVideoAssetsSync() → [AVAsset]（实况取配对视频，静态图生成 3s 视频）
  ├─ HardwareVideoCompositor.compose()
  │    ├─ AVMutableComposition 多轨合成
  │    ├─ BlockVideoCompositor（自定义 AVVideoCompositing）逐帧 BoxFit.cover 合成
  │    ├─ AVAssetReader + AVAssetWriter 硬编码输出
  │    └─ injectLivePhotoMetadata() 注入 content.identifier + still-image-time
  ├─ compositeHighResStill() → 高清封面合成
  ├─ writeCoverImage() → 嵌入 MakerApple 元数据
  └─ saveLivePhotoToLibrary() → PHPhotoLibrary 保存
```

### 4.3 模型契约

| 字段 | 语义 | 范围 |
|------|------|------|
| `ImageBlock.x/y/width/height` | 块在画布内的位置和尺寸 | 相对值 [0, 1] |
| `ImageBlock.offsetX/offsetY` | 图片在框内的平移偏移 | 画布像素 |
| `ImageBlock.scale` | 图片在框内的缩放比 | ≥ 0.1 |
| `CanvasConfig.width/height` | 画布逻辑尺寸 | 像素（默认基准 750） |
| `CompositorConfig.blocks[]` | 同 ImageBlock 的 x/y/w/h/scale/offsetX/offsetY | 相对值 + 像素混合 |

**Flutter ↔ Native 契约一致性**：两端的 block 字段语义必须完全对齐，任何变更需同步修改。

---

## 五、重难点分析

### ★★★ 难度最高

#### 1. 硬件加速视频合成（HardwareVideoCompositor + BlockVideoCompositor）

**文件**：`HardwareVideoCompositor.swift` / `BlockVideoCompositor.swift`

**核心挑战**：
- **多路视频实时合成**：N 路源视频需要在同一帧时间戳下合并为一个输出帧，每路按独立的 block 区域做 BoxFit.cover 裁剪和缩放
- **坐标系转换**：CIImage 使用 y-up 坐标系，UIKit/CGContext 使用 y-down，视频帧的 `preferredTransform` 会引入旋转（竖拍视频 90°），需要在 display 空间正确应用变换后再做 cover 裁剪
- **竖拍视频 180° 修正**：`preferredTransform` 是为 y-down 设计的，CIImage y-up 空间下含旋转的帧需额外补 180° 才能方向正确
- **用户平移方向映射**：`offsetX/offsetY` 在 Flutter（y-down）与 CIImage（y-up）间的符号需按 `isRotated` 分支处理
- **精确帧尺寸**：使用 `AVAssetReader(videoComposition)` + `AVAssetWriter` 管线代替 `AVAssetExportSession`，确保输出像素严格等于 `renderSize`，消除黑边

**关键代码路径**：
```
BlockVideoCompositor.startRequest()
  → drawBlock()  // 对每个 block 做 preferredTransform → 归一化 → 旋转修正 → cover 计算 → clip+draw
```

#### 2. Live Photo 元数据注入

**文件**：`HardwareVideoCompositor.swift` (`injectLivePhotoMetadata`)、`LivePhotoBridgePlugin.swift` (`createLivePhoto`)

**核心挑战**：
- iOS Photos 框架要求 Live Photo 的封面图和配对视频通过 **`com.apple.quicktime.content.identifier`** 配对
- 视频必须包含 **timed metadata track**（`com.apple.quicktime.still-image-time`）标记封面时间点
- 封面 JPEG 必须在 EXIF MakerApple 字典中嵌入 key `"17"` (identifier) 和 `"8"` (still image time)
- 元数据注入采用透传压缩流方式（`AVAssetReaderTrackOutput(outputSettings: nil)`），避免重编码质量损失
- 任一环节格式不正确，Photos 框架会静默降级为普通照片而非 Live Photo

#### 3. 共享边拖拽算法（Canvas Shared Edge）

**文件**：`canvas_shared_edge.dart`

**核心挑战**：
- 在任意 N 宫格布局中，自动识别两个相邻 block 之间的共享边（水平或垂直）
- 拖拽共享边时，需同时调整相邻 block 的 x/y/width/height，保证总和不变且不产生间隙
- 边界约束：每个 block 不能被压缩到最小尺寸以下
- 需处理 T 形交叉点（三个 block 共享一个顶点）的正确行为

---

### ★★ 难度较高

#### 4. 封面帧与播放同步

**文件**：`editor_cover_logic.dart` / `editor_playback_logic.dart` / `video_frame_selector_widget.dart`

**核心挑战**：
- 每张图片可独立设置封面帧时间（毫秒级），需从源 Live Photo 视频中实时提取对应帧预览
- 播放预览需要多路 `VideoPlayerController` 同步播放，动画控制器协调 2s 循环
- 封面帧时间需传递到导出流程的 `coverTimes` 参数，与原生合成器的 still-image-time 对齐

#### 5. 数据驱动画布交互（DataDrivenCanvas）

**文件**：`data_driven_canvas.dart` + `canvas_image_block_widget.dart`

**核心挑战**：
- 画布支持全局平移/缩放 + 单 block 内部的 pan/pinch 两级手势，需正确区分
- 图片在 block 内做 BoxFit.cover 渲染时，缩放和平移的坐标需要从画布相对坐标转换到屏幕像素
- 编辑时的 cover 溢出计算（`_calcCoverOverflow`）需与原生导出的 cover 裁剪算法保持一致
- 长按拖拽交换图片需要 hit-test 到目标 block 并触发平滑动画

#### 6. 静态图混合导出

**文件**：`LivePhotoHardwareExport.swift` (`fetchVideoAssetsSync` / `createStaticVideoFromImage`)

**核心挑战**：
- 当拼图中混合了 Live Photo 和普通静态图时，静态图需先生成固定时长（3s）的视频才能参与多轨合成
- 全部为静态图时走纯静态照片导出路径，不生成 Live Photo
- 静态视频的帧率（30fps）和时长需与合成器的 `targetDuration` 严格一致

---

### ★ 中等难度

#### 7. 布局引擎与模板系统

**文件**：`layout_engine.dart` / `layout_template.dart`

- 四种布局类型（grid / hierarchy / column / free）各有独立算法
- 模板定义使用相对权重，布局引擎转换为 [0,1] 相对坐标
- 支持间距（spacing）参数，间距值也是相对值
- 长图模式（`isLongImage`）需特殊处理画布比例和输出分辨率

#### 8. 照片加载与筛选体系

**文件**：`photo_provider.dart` / `live_photo_manager.dart` / `photo_selection_screen.dart`

- 双重来源：`photo_manager`（PHAsset）+ `LivePhotoBridge`（原生 Live Photo ID）
- 分页加载 + 实况/全部筛选 + 相册切换
- Live Photo 识别依赖原生桥接返回的 ID 集合做交叉匹配
- 全屏画廊浏览 + 缩略图性能优化

#### 9. 高清封面合成

**文件**：`LivePhotoHardwareExport.swift` (`compositeHighResStill`)

- 封面图需要比视频更高的分辨率（标准模式 3024px，长图模式动态计算）
- 每张图的封面来源二选一：自定义帧时间 → 从视频提取 | 默认 → PHAsset 全分辨率原图
- UIGraphics 合成时需精确复现 BoxFit.cover 裁剪 + 用户 offset/scale

---

## 六、关键依赖

| 依赖 | 用途 |
|------|------|
| `flutter_riverpod` | 状态管理 |
| `photo_manager` | 相册访问、PHAsset 操作 |
| `video_player` | 视频播放预览 |
| `image` | Dart 侧图片处理 |
| `image_cropper` | 图片裁剪 |
| `shared_preferences` | 本地持久化（语言、历史） |
| `share_plus` | 分享功能 |
| `image_gallery_saver` | 保存到相册（Dart 侧备用） |
| `path_provider` | 临时文件路径 |
| `permission_handler` | 权限请求 |
| `flutter_colorpicker` | 颜色选择器 |
| `uuid` | 唯一标识生成 |
| `live_photo_bridge`（本地插件） | Flutter ↔ iOS 原生通信 |

---

## 七、编辑器状态机

```
EditorState.global     ← 全局编辑模式（画布比例、布局切换）
    │
    │  点击某个 block
    ▼
EditorState.single     ← 单图编辑模式（平移、缩放、设封面）
    │
    │  点击画布空白 / 完成编辑
    ▼
EditorState.global
```

工具栏动态切换：
- **GlobalTool**：`ratio`（画布比例）、`layout`（布局模板）
- **SingleTool**：`cover`（封面帧）、`crop`（裁剪）

---

## 八、文件拆分策略

### Dart 大文件拆分

编辑器主文件 `puzzle_editor_screen.dart` 采用 **`part` / `part of`** 机制拆分为 6 个文件：

| 文件 | 职责 |
|------|------|
| `puzzle_editor_screen.dart` | State 字段定义、`build()`、`initState/dispose` |
| `editor_export_logic.dart` | 导出/保存到相册全流程 |
| `editor_playback_logic.dart` | 播放预览控制 |
| `editor_cover_logic.dart` | 封面帧设置 |
| `editor_layout_logic.dart` | 布局切换算法 |
| `editor_session_load.dart` | 会话初始化/照片加载 |

其他大文件通过**提取独立 Widget/辅助类**到子目录拆分。

### Swift 大文件拆分

`LivePhotoBridgePlugin` 使用 **extension** 机制拆分为 3 个文件：

| 文件 | 职责 |
|------|------|
| `LivePhotoBridgePlugin.swift` | 插件注册、方法分发、软件 Live Photo 创建 |
| `LivePhotoAssetService.swift` | PHAsset 操作（获取 ID、视频路径、帧提取、时长） |
| `LivePhotoHardwareExport.swift` | 硬件加速合成 + 封面 + 相册保存 |

---

## 九、已知技术债务

1. **`setState` in extension warning**：`part` 文件中的 extension 方法调用 `setState` 会产生 `invalid_use_of_protected_member` lint 警告（运行时正常）
2. **双轨数据模型**：编辑器同时维护新系统（`ImageBlock`）和旧帧序列（`_videoFrames`/`_selectedFrames`），导出时两套数据需要同步
3. **仅 iOS 支持**：Android 侧原生插件尚未实现 `createLivePhotoHardware`
4. **视频 Controller 生命周期**：多路 `VideoPlayerController` 的创建/释放与编辑器页面生命周期耦合较紧
