# LivePuzzle

一款支持iOS和Android的Live Photo拼图应用，让你可以将多个Live Photo组合成精美的拼图，并保留动态效果。

## 🎯 功能特性

- **Live Photo选择与帧选择**：从设备相册选择多个Live Photo，精确选择每个Live Photo的定格帧
- **多种布局模板**：支持2x2、3x3、2x3网格等多种拼图布局
- **拼图编辑功能**：图片调整、旋转、滤镜等编辑功能
- **Live Photo生成**：将拼图重新生成为Live Photo格式，保留动态效果
- **精美UI设计**：Material Design 3风格，支持深色模式

## 🏗️ 技术架构

### 核心技术栈

- **框架**：Flutter 3.x
- **状态管理**：Riverpod
- **UI设计**：Material Design 3
- **视频处理**：FFmpeg Kit
- **图片处理**：Image Package

### 核心功能模块

1. **Live Photo管理器** (`lib/services/live_photo_manager.dart`)
   - 识别和加载Live Photo/Motion Photo
   - iOS平台：通过Platform Channel调用PHLivePhoto API
   - Android平台：解析Motion Photo格式（JPEG+内嵌MP4）

2. **帧提取器** (`lib/services/frame_extractor.dart`)
   - 从Live Photo中提取视频帧
   - 支持按时间点或索引提取帧
   - 批量提取关键帧

3. **拼图生成器** (`lib/services/puzzle_generator.dart`)
   - 多个帧组合成拼图图片
   - 支持多种布局模板
   - 图片缩放、旋转、位置调整

4. **Live Photo创建器** (`lib/services/live_photo_creator.dart`)
   - 将拼图重新生成为Live Photo格式
   - 使用FFmpeg合成视频
   - iOS：生成PHLivePhoto兼容文件
   - Android：生成Motion Photo格式

## 📦 主要依赖库

```yaml
dependencies:
  flutter_riverpod: ^2.4.9      # 状态管理
  photo_manager: ^3.0.0          # 相册访问
  image_picker: ^1.0.5           # 图片选择
  image: ^4.1.3                  # 图片处理
  video_player: ^2.8.1           # 视频播放
  ffmpeg_kit_flutter: ^6.0.3     # 视频处理
  path_provider: ^2.1.1          # 文件系统
  permission_handler: ^11.0.1    # 权限管理
  uuid: ^4.2.1                   # UUID生成
```

## 🚀 快速开始

### 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- iOS 13.0+ / Android 6.0+ (API 23+)
- Xcode 14+ (iOS开发)
- Android Studio / VS Code

### 安装步骤

```bash
# 1. 克隆项目（如果从git获取）
git clone <repository-url>
cd LivePuzzle

# 2. 获取依赖
flutter pub get

# 3. 运行应用（iOS）
flutter run -d ios

# 4. 运行应用（Android）
flutter run -d android
```

### 打包发布

```bash
# iOS打包
flutter build ios --release

# Android打包
flutter build apk --release
flutter build appbundle --release
```

## 📱 平台特定配置

### iOS配置

1. **Info.plist权限配置** (`ios/Runner/Info.plist`)

已自动配置以下权限：

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册以选择Live Photo</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>需要保存生成的Live Photo到相册</string>
```

2. **原生代码** (`ios/Runner/LivePhotoPlugin.swift`)
   - PHLivePhoto处理
   - 视频帧提取
   - Live Photo创建和保存

### Android配置

1. **AndroidManifest.xml权限配置**

已自动配置以下权限：

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
```

2. **原生代码** (`android/app/src/main/kotlin/.../MainActivity.kt`)
   - Motion Photo识别和解析
   - 视频帧提取
   - Motion Photo创建和保存

## 📂 项目结构

```
LivePuzzle/
├── lib/
│   ├── main.dart                       # 应用入口
│   ├── models/                         # 数据模型
│   │   ├── live_photo.dart            # Live Photo模型
│   │   ├── frame_data.dart            # 帧数据模型
│   │   ├── puzzle_layout.dart         # 拼图布局模型
│   │   └── puzzle_project.dart        # 拼图项目模型
│   ├── services/                       # 业务逻辑服务
│   │   ├── live_photo_manager.dart    # Live Photo管理
│   │   ├── frame_extractor.dart       # 帧提取
│   │   ├── puzzle_generator.dart      # 拼图生成
│   │   └── live_photo_creator.dart    # Live Photo创建
│   ├── providers/                      # Riverpod状态管理
│   │   ├── photo_provider.dart        # 照片状态
│   │   └── puzzle_provider.dart       # 拼图状态
│   ├── screens/                        # 页面
│   │   ├── home_screen.dart           # 主页
│   │   ├── photo_selection_screen.dart # 照片选择
│   │   ├── layout_selection_screen.dart # 布局选择
│   │   ├── frame_selector_screen.dart  # 帧选择
│   │   ├── puzzle_editor_screen.dart   # 拼图编辑
│   │   └── preview_screen.dart         # 预览导出
│   ├── widgets/                        # UI组件
│   │   ├── frame_timeline.dart        # 帧时间轴
│   │   ├── puzzle_canvas.dart         # 拼图画布
│   │   └── layout_templates.dart      # 布局模板选择器
│   └── utils/                          # 工具类
│       ├── permissions.dart           # 权限管理
│       └── file_helpers.dart          # 文件操作
├── ios/                                # iOS平台代码
│   └── Runner/
│       ├── AppDelegate.swift
│       └── LivePhotoPlugin.swift      # iOS原生插件
├── android/                            # Android平台代码
│   └── app/src/main/kotlin/.../
│       └── MainActivity.kt            # Android原生代码
├── assets/                             # 资源文件
│   ├── images/                        # 图片资源
│   └── templates/                     # 模板资源
├── pubspec.yaml                        # 依赖配置
└── README.md                           # 项目文档
```

## 🎨 应用流程

1. **启动页面** → 权限请求 → 进入主页
2. **选择Live Photo** → 从相册中选择多个Live Photo
3. **选择布局** → 选择拼图布局模板（2x2、3x3等）
4. **选择帧** → 为每个位置选择特定的帧
5. **编辑拼图** → 调整图片位置、旋转、滤镜等
6. **预览导出** → 预览效果并导出为Live Photo

## 🔧 开发说明

### 代码规范

- 每个文件大小控制在500行内，合理拆分组件
- 使用单引号字符串
- 遵循Flutter官方代码风格
- 使用Riverpod进行状态管理
- 使用Material Design 3组件

### 调试技巧

```bash
# 查看日志
flutter logs

# 热重载
r (在运行中按r)

# 热重启
R (在运行中按R)

# 性能分析
flutter run --profile
```

## 📝 待完善功能

- [ ] 完善帧提取器UI和功能
- [ ] 添加更多布局模板（创意拼贴、自由排列等）
- [ ] 实现图片编辑功能（裁剪、滤镜、调整等）
- [ ] 完善原生代码的Live Photo生成逻辑
- [ ] 添加视频合成功能
- [ ] 优化性能和内存使用
- [ ] 添加单元测试和集成测试

## 🐛 已知问题

- 原生平台的Live Photo提取和生成功能需要进一步完善
- FFmpeg视频合成功能待实现
- Motion Photo格式解析需要优化

## 🤝 贡献指南

欢迎提交Issue和Pull Request来改进这个项目！

## 📄 许可证

MIT License
