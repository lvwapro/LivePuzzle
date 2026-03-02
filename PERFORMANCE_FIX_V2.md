# 性能优化 v2 - AVAssetReader 流式读取

## 🐛 问题诊断

**原因**：使用 `AVAssetImageGenerator.copyCGImage()` 逐帧提取太慢

### 性能瓶颈分析：

```swift
// ❌ 旧版（极慢）
for frameIndex in 0..<90 {
    for asset in videoAssets {  // 2-9 个视频
        let cgImage = try generator.copyCGImage(at: time)  // 同步阻塞！
        // 90帧 × 2-9视频 = 180-810次昂贵的解码
    }
}
```

**实测耗时**：
- 2张照片：~15-20秒（每帧 ~150-220ms）
- 比软编码还慢！

## ✅ 解决方案

使用 `AVAssetReader` 流式读取（真正的硬件加速）

```swift
// ✅ 新版（极快）
let readers = try createAssetReaders()  // 一次性创建
while frameIndex < 90 {
    for reader in readers {
        let buffer = readNextFrame(from: reader.output)  // 流式读取，零拷贝
    }
}
```

### 关键优化：

1. **流式读取**：`AVAssetReaderTrackOutput` 连续读取，无需重复创建
2. **零拷贝**：直接输出 CVPixelBuffer，无 CGImage 转换
3. **硬件解码**：AVAssetReader 使用 VideoToolbox 硬件解码
4. **减少调用**：`AVAssetImageGenerator` 仅用于封面（2-9次）

## 📊 预期性能

### 之前（AVAssetImageGenerator）：
```
提取封面: 0.5s
逐帧读取: 15-18s  ❌ 太慢
GPU 合成: 1.5s
硬编码: 0.5s
总计: ~18s
```

### 现在（AVAssetReader）：
```
提取封面: 0.5s
流式读取+合成+编码: 1.5-2s  ✅ 极快
总计: ~2-2.5s
```

**提升**: 18s → 2.5s = **7-8倍**

## 🔧 技术细节

### AVAssetReader 配置

```swift
let outputSettings: [String: Any] = [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
]
output.alwaysCopiesSampleData = false  // 零拷贝！
```

### 流式读取

```swift
while let sampleBuffer = output.copyNextSampleBuffer() {
    let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    // 直接用于 GPU 合成，无需格式转换
}
```

## 🧪 测试验证

测试时观察日志：

```
📹 创建视频读取器...          // 新增
✅ 读取器创建完成: X个
📹 开始硬件编码: 90 帧...
📹 已编码 30/90 帧           // 应该很快
📹 已编码 60/90 帧
✅ 硬件编码完成: 耗时 1.5s   // 目标 <3秒
⏱️ 硬件加速导出完成，总耗时 2XXXms
```

## ⚠️ 注意事项

1. **内存管理**：使用 `autoreleasepool` 避免内存堆积
2. **错误处理**：reader 失败时回退到封面帧
3. **时长对齐**：超过视频时长时使用封面帧

---

**优化版本**: v2  
**预期提升**: 7-8倍（18s → 2.5s）  
**状态**: ✅ 已实现，待测试
