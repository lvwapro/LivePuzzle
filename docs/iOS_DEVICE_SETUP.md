# iOS真机调试配置指南

## 🎯 当前状态

✅ **设备已连接**: 绿瓦的 iPhone (iOS 18.5)  
✅ **Flutter已识别**: 设备ID `00008120-000904213440201E`

## 📱 配置步骤

### 方法1: 使用Xcode配置（推荐）

我已经为你打开了Xcode，请按以下步骤操作：

#### 1. 在Xcode中配置签名

1. **选择项目**
   - 点击左侧的 `Runner` 项目

2. **选择TARGETS**
   - 选择 `Runner` target

3. **配置Signing & Capabilities**
   - 找到 "Signing & Capabilities" 标签页
   - ✅ 勾选 "Automatically manage signing"
   - 在 "Team" 下拉菜单中选择你的Apple账号
   - 如果没有账号，点击 "Add Account..." 添加

4. **修改Bundle Identifier**
   - 将默认的 `com.example.livePuzzle` 改为你的唯一标识
   - 建议格式: `com.yourname.livePuzzle`
   - 例如: `com.greenwa.livePuzzle`

5. **选择开发团队**
   - Team: 选择你的 Apple ID 或开发者账号
   - 会自动生成证书和配置文件

#### 2. 信任开发者证书（首次运行）

在iPhone上：
1. 打开 **设置** > **通用** > **VPN与设备管理**
2. 找到你的开发者应用
3. 点击 **信任**

### 方法2: 使用Flutter命令（快速）

如果Xcode配置已完成，可以直接运行：

```bash
# 方式1: 指定设备ID运行
flutter run -d 00008120-000904213440201E

# 方式2: 指定平台运行（会自动选择iPhone）
flutter run -d ios

# 方式3: 以release模式运行（性能更好）
flutter run -d ios --release
```

## ⚠️ 常见问题

### 问题1: "No Development Team Selected"

**解决方法**:
1. 打开Xcode项目
2. 添加你的Apple ID：Xcode > Preferences > Accounts > "+"
3. 在项目中选择这个Team

### 问题2: "Failed to code sign"

**解决方法**:
1. 确保Bundle Identifier是唯一的
2. 清理构建缓存：
```bash
cd ios
rm -rf Pods
rm Podfile.lock
pod install
cd ..
flutter clean
```

### 问题3: "App installation failed"

**解决方法**:
1. 检查iPhone存储空间是否充足
2. 在iPhone上信任开发者证书
3. 重启iPhone和Xcode

### 问题4: 权限问题

确保Info.plist已经配置了所需权限（已配置）:
- ✅ NSPhotoLibraryUsageDescription
- ✅ NSPhotoLibraryAddUsageDescription

## 🚀 快速运行

一旦配置完成，运行：

```bash
# 进入项目目录
cd /Users/huangct/Documents/learn/myGithub/my-app/LivePuzzle

# 运行到iPhone
flutter run

# 或者指定设备
flutter run -d "绿瓦的 iPhone"
```

## 📝 调试技巧

### 查看日志
```bash
# 实时查看日志
flutter logs

# 查看详细日志
flutter run -v
```

### 热重载
- 保存文件后自动重载：`r`
- 完全重启：`R`
- 清除状态：`flutter clean`

### 性能模式
```bash
# Profile模式（性能分析）
flutter run --profile

# Release模式（最佳性能）
flutter run --release
```

## ✅ 验证安装

运行后，在iPhone上：
1. 打开LivePuzzle应用
2. 授予相册权限
3. 测试选择Live Photo功能
4. 测试定格帧选择功能

## 🎯 下一步

配置完成后，你可以：
1. ✅ 真机测试所有功能
2. ✅ 测试Live Photo拼图生成
3. ✅ 验证性能表现
4. ✅ 收集实际使用反馈

---

**需要帮助？** 告诉我遇到什么问题，我会帮你解决！
