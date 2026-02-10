# Live Photo 元数据调试指南

## 已添加的元数据

### 图片（JPEG）元数据
在 `kCGImagePropertyMakerAppleDictionary` 中：
- **键 "17"**: Content Identifier（UUID 字符串）
  - 用于配对图片和视频
  - 格式：UUID 字符串，例如 "A1B2C3D4-..."
  
- **键 "8"**: Still Image Time（字符串格式的秒数）
  - 表示视频中的关键帧位置
  - 格式：浮点数字符串，例如 "0.000000"
  - 当前设置为 "0.000000"（视频开始）

### 视频（MOV）元数据
QuickTime 元数据轨道中：
- **com.apple.quicktime.content.identifier**
  - 与图片中的键17相同的 UUID
  - 用于配对
  
- **com.apple.quicktime.still-image-time**
  - CMTime 格式的时间标记
  - 表示关键帧在视频中的位置
  - 当前设置为 CMTime(value: 0, timescale: 15)

## 验证方法

### 1. 使用 exiftool 检查元数据（Mac）

```bash
# 安装 exiftool
brew install exiftool

# 检查保存的 Live Photo
# 在照片应用中找到保存的 Live Photo，右键 > 显示简介 > 获取文件路径

# 检查图片元数据
exiftool /path/to/live_photo.jpg | grep -i "maker\|apple\|content"

# 检查视频元数据
exiftool /path/to/live_photo.mov | grep -i "content\|still"
```

### 2. 使用 iOS 照片应用检查

保存 Live Photo 后：
1. 打开照片应用
2. 找到保存的 Live Photo
3. 点击"编辑"
4. 如果支持实况定格：
   - 应该能看到时间轴
   - 可以拖动选择关键帧
   - 底部有"选为关键照片"选项

### 3. 使用 Xcode 控制台查看日志

运行应用时在 Xcode 控制台中查找：
```
📝 iOS原生: 添加元数据 - Identifier: [UUID], StillTime: 0.000000s
📝 iOS原生: 视频元数据 - ContentID: [UUID], StillTime: CMTime(...)
```

## 常见问题

### Q: 为什么保存的 Live Photo 不支持实况定格？

可能的原因：
1. **元数据格式不正确**
   - MakerApple 字典的键和值格式必须正确
   - Still Image Time 必须是有效的时间值

2. **配对标识符不匹配**
   - 图片和视频的 Content Identifier 必须完全相同

3. **视频时长问题**
   - Live Photo 视频应该在 1-3 秒之间
   - 当前设置：30帧 @ 15fps = 2秒 ✓

4. **文件格式问题**
   - 图片必须是 JPEG
   - 视频必须是 H.264 编码的 MOV

### Q: 如何测试修复是否有效？

1. 保存一个 Live Photo
2. 在照片应用中打开它
3. 点击"编辑"
4. 查看是否有时间轴和"选为关键照片"选项

## 技术参考

### Apple Live Photo 规范
- 图片和视频通过 Content Identifier（UUID）配对
- 图片的 MakerApple 字典键17存储配对 ID
- 图片的 MakerApple 字典键8存储 Still Image Time
- 视频的 QuickTime 元数据包含相同的 Content Identifier
- 视频的 Still Image Time 标记关键帧位置

### CMTime 结构
```swift
CMTime(
    value: Int64,      // 时间值
    timescale: Int32   // 时间刻度（每秒的单位数）
)
// 实际秒数 = value / timescale
```

## 下一步调试

如果实况定格仍然不工作，尝试：
1. 检查真实的 Live Photo 的元数据格式
2. 使用 `exiftool` 对比差异
3. 确认 Still Image Time 的确切格式要求
4. 考虑添加其他可能需要的元数据字段
