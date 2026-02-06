import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_puzzle/models/live_photo.dart';
import 'package:live_puzzle/models/frame_data.dart';
import 'package:live_puzzle/providers/puzzle_provider.dart';
import 'package:live_puzzle/providers/photo_provider.dart';
import 'package:live_puzzle/services/live_photo_manager.dart';
import 'package:live_puzzle/services/frame_extractor.dart';
import 'package:live_puzzle/widgets/frame_timeline.dart';
import 'package:live_puzzle/screens/puzzle_editor_screen.dart';

/// 帧选择器页面 - 为拼图的每个位置选择定格帧
class FrameSelectorScreen extends ConsumerStatefulWidget {
  const FrameSelectorScreen({super.key});

  @override
  ConsumerState<FrameSelectorScreen> createState() =>
      _FrameSelectorScreenState();
}

class _FrameSelectorScreenState extends ConsumerState<FrameSelectorScreen> {
  List<LivePhoto> _livePhotos = [];
  Map<int, FrameData> _selectedFrames = {}; // position -> FrameData
  int _currentPosition = 0;
  bool _isLoading = true;
  Duration _currentTimestamp = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadLivePhotos();
  }

  Future<void> _loadLivePhotos() async {
    final selectedIds = ref.read(selectedLivePhotoIdsProvider);
    final photos = <LivePhoto>[];

    for (final id in selectedIds) {
      final photo = await LivePhotoManager.getLivePhotoById(id);
      if (photo != null) {
        photos.add(photo);
      }
    }

    setState(() {
      _livePhotos = photos;
      _isLoading = false;
    });

    // 自动加载第一个Live Photo的第一帧作为默认选择
    if (_livePhotos.isNotEmpty) {
      _loadDefaultFrame(0);
    }
  }

  Future<void> _loadDefaultFrame(int position) async {
    if (position >= _livePhotos.length) return;

    final livePhoto = _livePhotos[position];
    // 获取视频的最后一帧作为定格帧
    final frame = await FrameExtractor.extractFrameAtTime(
      livePhoto,
      livePhoto.duration,
    );

    if (frame != null && mounted) {
      setState(() {
        _selectedFrames[position] = frame;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(puzzleProjectProvider);

    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('选择定格帧')),
        body: const Center(child: Text('项目数据错误')),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('选择定格帧')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_livePhotos.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('选择定格帧')),
        body: const Center(child: Text('没有选择Live Photo')),
      );
    }

    final totalCells = project.layout.cells.length;
    final maxPhotos = totalCells < _livePhotos.length ? totalCells : _livePhotos.length;
    final completedFrames = _selectedFrames.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('选择定格帧 ($completedFrames/$maxPhotos)'),
        actions: [
          if (completedFrames == maxPhotos)
            TextButton.icon(
              onPressed: _saveAndContinue,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('完成', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // 进度指示器
          LinearProgressIndicator(
            value: completedFrames / maxPhotos,
            minHeight: 6,
          ),
          const SizedBox(height: 16),

          // 位置选择器
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: maxPhotos,
              itemBuilder: (context, index) {
                final isSelected = _currentPosition == index;
                final hasFrame = _selectedFrames.containsKey(index);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentPosition = index;
                      _currentTimestamp = Duration.zero;
                    });
                  },
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasFrame ? Colors.green : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          hasFrame ? Icons.check_circle : Icons.panorama,
                          color: isSelected ? Colors.white : Colors.grey,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '位置 ${index + 1}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // 当前Live Photo信息
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.photo_library, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Live Photo ${_currentPosition + 1}/${_livePhotos.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '时长: ${_livePhotos[_currentPosition].duration.inSeconds}秒',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 24),

          // 帧时间轴选择器
          Expanded(
            child: _currentPosition < _livePhotos.length
                ? FrameTimeline(
                    key: ValueKey(_currentPosition),
                    livePhoto: _livePhotos[_currentPosition],
                    selectedTimestamp: _currentTimestamp,
                    onTimestampChanged: (timestamp) {
                      setState(() {
                        _currentTimestamp = timestamp;
                      });
                    },
                  )
                : const Center(child: Text('没有更多Live Photo')),
          ),

          // 底部操作栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _currentPosition > 0
                              ? () {
                                  setState(() {
                                    _currentPosition--;
                                    _currentTimestamp = Duration.zero;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('上一个'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _selectCurrentFrame,
                          icon: const Icon(Icons.check),
                          label: const Text('选择此帧'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _currentPosition < maxPhotos - 1
                              ? () {
                                  setState(() {
                                    _currentPosition++;
                                    _currentTimestamp = Duration.zero;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('下一个'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectCurrentFrame() async {
    if (_currentPosition >= _livePhotos.length) return;

    // 显示加载指示器
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在提取帧...'),
              ],
            ),
          ),
        ),
      ),
    );

    final livePhoto = _livePhotos[_currentPosition];
    final frame = await FrameExtractor.extractFrameAtTime(
      livePhoto,
      _currentTimestamp,
    );

    if (!mounted) return;
    Navigator.pop(context); // 关闭加载对话框

    if (frame != null) {
      setState(() {
        _selectedFrames[_currentPosition] = frame;
      });

      // 保存到项目
      final selectedFrame = SelectedFrame(
        livePhotoId: livePhoto.id,
        frameData: frame,
        positionInPuzzle: _currentPosition,
      );

      ref.read(puzzleProjectProvider.notifier).addFrame(selectedFrame);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已选择位置 ${_currentPosition + 1} 的定格帧'),
          duration: const Duration(seconds: 1),
        ),
      );

      // 自动跳到下一个
      final project = ref.read(puzzleProjectProvider);
      if (project != null) {
        final maxPhotos = project.layout.cells.length < _livePhotos.length
            ? project.layout.cells.length
            : _livePhotos.length;

        if (_currentPosition < maxPhotos - 1) {
          setState(() {
            _currentPosition++;
            _currentTimestamp = Duration.zero;
          });
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('提取帧失败，请重试'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _saveAndContinue() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PuzzleEditorScreen(),
      ),
    );
  }
}
