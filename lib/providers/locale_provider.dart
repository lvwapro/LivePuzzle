import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 语言Provider
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _loadLocale();
  }

  static const String _localeKey = 'app_locale';

  /// 从本地存储加载语言设置
  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_localeKey);
      
      if (languageCode != null) {
        state = Locale(languageCode);
      }
    } catch (e) {
      print('加载语言设置失败: $e');
    }
  }

  /// 设置语言
  Future<void> setLocale(Locale locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale.languageCode);
      state = locale;
    } catch (e) {
      print('保存语言设置失败: $e');
    }
  }

  /// 清除语言设置（使用系统语言）
  Future<void> clearLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localeKey);
      state = null;
    } catch (e) {
      print('清除语言设置失败: $e');
    }
  }
}
