# 相册权限配置指南

## 📱 iOS 权限说明

### 已配置的权限

在 `ios/Runner/Info.plist` 中已经添加了以下权限：

#### 1. **读取相册权限**
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册以选择Live Photo</string>
```

#### 2. **写入相册权限**
```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>需要保存生成的Live Photo到相册</string>
```

---

## 🔧 如何使用权限

### 首次启动应用

1. **安装应用**
   ```bash
   flutter run -d "绿瓦的 iPhone"
   ```

2. **应用会在启动时自动请求相册权限**
   - 当你点击"选择照片"按钮时
   - 系统会弹出权限请求对话框
   - 显示文字："需要访问相册以选择Live Photo"

3. **授予权限**
   - 点击"允许访问所有照片"（推荐）
   - 或"选择照片..."（选择部分照片）

---

## ⚠️ 常见问题

### 问题1: 没有弹出权限请求
**原因**: 可能之前拒绝过权限

**解决方法**:
1. 打开 iPhone **设置**
2. 找到 **Live Puzzle** 应用
3. 点击 **照片**
4. 选择 **所有照片** 或 **选定的照片**

### 问题2: 选择照片后应用崩溃
**原因**: 权限未正确授予

**解决方法**:
1. 重新安装应用
2. 或按照"问题1"的方法手动授予权限

### 问题3: 无法保存生成的Live Photo
**原因**: 没有写入相册权限

**解决方法**:
1. 打开 iPhone **设置** → **Live Puzzle** → **照片**
2. 确保选择了 **所有照片** 或 **添加照片**

---

## 🔍 权限检查代码

应用使用 `permission_handler` 包来管理权限：

```dart
import 'package:permission_handler/permission_handler.dart';

// 检查并请求相册权限
Future<bool> requestPhotoPermission() async {
  var status = await Permission.photos.status;
  
  if (status.isDenied) {
    // 请求权限
    status = await Permission.photos.request();
  }
  
  return status.isGranted || status.isLimited;
}
```

---

## 📝 Android 权限（未来支持）

当支持Android时，需要在 `android/app/src/main/AndroidManifest.xml` 中添加：

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
```

---

## ✅ 当前状态

- ✅ iOS相册读取权限已配置
- ✅ iOS相册写入权限已配置
- ✅ 权限描述已本地化（中文）
- ⏳ 应用启动时自动请求权限（待测试）
- ⏳ Android权限配置（待实现）

---

## 🚀 下一步

运行应用后：
1. 观察是否正确弹出权限请求
2. 授予相册访问权限
3. 测试选择Live Photo功能
4. 测试保存生成的Live Photo功能

如果遇到任何权限相关问题，请参考上述"常见问题"部分。
