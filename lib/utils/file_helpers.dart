import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 文件辅助工具类
class FileHelper {
  /// 获取临时目录
  static Future<Directory> getTempDirectory() async {
    return await getTemporaryDirectory();
  }

  /// 获取应用文档目录
  static Future<Directory> getAppDocDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  /// 创建唯一的临时文件路径
  static Future<String> createTempFilePath(String extension) async {
    final tempDir = await getTempDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'live_puzzle_$timestamp.$extension';
    return path.join(tempDir.path, filename);
  }

  /// 复制文件
  static Future<File> copyFile(String sourcePath, String destPath) async {
    final sourceFile = File(sourcePath);
    return await sourceFile.copy(destPath);
  }

  /// 删除文件
  static Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 检查文件是否存在
  static Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  /// 获取文件大小
  static Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    return await file.length();
  }

  /// 清理临时文件
  static Future<void> cleanTempFiles() async {
    final tempDir = await getTempDirectory();
    final files = tempDir.listSync();
    for (final file in files) {
      if (file is File && file.path.contains('live_puzzle_')) {
        try {
          await file.delete();
        } catch (e) {
          // 忽略删除错误
        }
      }
    }
  }
}
