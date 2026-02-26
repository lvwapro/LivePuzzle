import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/puzzle_history.dart';

/// 历史记录Provider
final puzzleHistoryProvider = StateNotifierProvider<PuzzleHistoryNotifier, List<PuzzleHistory>>((ref) {
  return PuzzleHistoryNotifier();
});

class PuzzleHistoryNotifier extends StateNotifier<List<PuzzleHistory>> {
  PuzzleHistoryNotifier() : super([]) {
    _loadHistory();
  }

  static const String _storageKey = 'puzzle_history';
  static const int _maxHistoryCount = 20; // 最多保存20条历史记录

  /// 从本地存储加载历史记录
  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        final histories = jsonList
            .map((json) => PuzzleHistory.fromJson(json as Map<String, dynamic>))
            .toList();
        
        // 按创建时间倒序排序
        histories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        state = histories;
      }
    } catch (e) {
      print('加载历史记录失败: $e');
      state = [];
    }
  }

  /// 保存历史记录到本地存储
  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = state.map((h) => h.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(jsonList));
    } catch (e) {
      print('保存历史记录失败: $e');
    }
  }

  /// 添加新的历史记录
  Future<void> addHistory(PuzzleHistory history) async {
    final newList = [history, ...state];
    
    // 限制历史记录数量
    if (newList.length > _maxHistoryCount) {
      state = newList.take(_maxHistoryCount).toList();
    } else {
      state = newList;
    }
    
    await _saveHistory();
  }

  /// 删除历史记录
  Future<void> removeHistory(String id) async {
    state = state.where((h) => h.id != id).toList();
    await _saveHistory();
  }

  /// 清空所有历史记录
  Future<void> clearAll() async {
    state = [];
    await _saveHistory();
  }

  /// 获取最近的N条历史记录
  List<PuzzleHistory> getRecent(int count) {
    return state.take(count).toList();
  }
}
