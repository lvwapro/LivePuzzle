import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

/// 权限管理工具类
class PermissionHelper {
  /// 请求相册权限 (使用photo_manager)
  static Future<bool> requestPhotoLibraryPermission() async {
    print('🔐 Requesting photo library permission using PhotoManager...');
    
    // 使用PhotoManager的权限请求
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    print('📸 PhotoManager permission state: $ps');
    
    if (ps.isAuth) {
      // 权限已授予
      print('✅ Permission granted');
      return true;
    } else if (ps.hasAccess) {
      // 有部分访问权限（iOS的limited）
      print('✅ Permission limited (has access)');
      return true;
    } else {
      // 权限被拒绝
      print('❌ Permission denied: $ps');
      return false;
    }
  }

  /// 请求存储权限（Android）
  static Future<bool> requestStoragePermission() async {
    // iOS不需要单独的存储权限
    if (Platform.isIOS) {
      return true;
    }
    
    final status = await Permission.storage.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isDenied) {
      final result = await Permission.storage.request();
      return result.isGranted;
    }
    
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    
    return false;
  }

  /// 请求所有必要权限
  static Future<bool> requestAllPermissions() async {
    print('🔐 Requesting all permissions...');
    
    // iOS只需要photos权限，Live Photo包含在其中
    if (Platform.isIOS) {
      return await requestPhotoLibraryPermission();
    }
    
    // Android需要存储和照片权限
    final photoGranted = await requestPhotoLibraryPermission();
    final storageGranted = await requestStoragePermission();
    
    return photoGranted && storageGranted;
  }
  
  /// 检查是否有相册权限
  static Future<bool> hasPhotoPermission() async {
    final ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth || ps.hasAccess;
  }
  
  /// 直接打开应用设置页面
  static Future<void> openSettings() async {
    print('⚙️ Opening app settings...');
    // 使用PhotoManager的打开设置方法
    await PhotoManager.openSetting();
  }
}
