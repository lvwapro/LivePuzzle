import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart' as photo_manager;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:live_puzzle/l10n/app_localizations.dart';
import 'package:live_puzzle/services/image_split_service.dart';
import 'photo_selection/photo_thumbnail_widget.dart';
import 'image_split/split_grid_painters.dart';

// ── 数据模型 ──

class SplitPattern {
  final String id;
  final int rows;
  final int cols;
  final String label;
  const SplitPattern({
    required this.id,
    required this.rows,
    required this.cols,
    required this.label,
  });
  int get count => rows * cols;
}

class CropRatio {
  final String label;
  final double? ratio;
  const CropRatio(this.label, this.ratio);
}

const _kPatterns = [
  SplitPattern(id: '1x2', rows: 1, cols: 2, label: '1×2'),
  SplitPattern(id: '2x1', rows: 2, cols: 1, label: '2×1'),
  SplitPattern(id: '1x3', rows: 1, cols: 3, label: '1×3'),
  SplitPattern(id: '3x1', rows: 3, cols: 1, label: '3×1'),
  SplitPattern(id: '2x2', rows: 2, cols: 2, label: '2×2'),
  SplitPattern(id: '2x3', rows: 2, cols: 3, label: '2×3'),
  SplitPattern(id: '3x3', rows: 3, cols: 3, label: '3×3'),
];

const _kRatios = [
  CropRatio('Original', null),
  CropRatio('1:1', 1.0),
  CropRatio('3:4', 3 / 4),
  CropRatio('4:3', 4 / 3),
  CropRatio('9:16', 9 / 16),
  CropRatio('16:9', 16 / 9),
];

/// 切图页面 - 选择照片 → 裁剪比例 → 网格切割 → 保存
class ImageSplitScreen extends StatefulWidget {
  const ImageSplitScreen({super.key});

  @override
  State<ImageSplitScreen> createState() => _ImageSplitScreenState();
}

class _ImageSplitScreenState extends State<ImageSplitScreen> {
  // 照片列表
  List<photo_manager.AssetEntity> _assets = [];
  bool _loadingAssets = true;

  // 编辑状态
  photo_manager.AssetEntity? _selectedAsset;
  Uint8List? _fullImageData;
  bool _loadingImage = false;
  SplitPattern _selectedPattern = _kPatterns[6];
  CropRatio _selectedCropRatio = _kRatios[0];
  double _alignX = 0.0;
  double _alignY = 0.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final albums = await photo_manager.PhotoManager.getAssetPathList(
      type: photo_manager.RequestType.image,
      hasAll: true,
    );
    if (albums.isEmpty) {
      if (mounted) setState(() => _loadingAssets = false);
      return;
    }
    final album = albums.firstWhere(
      (a) => a.isAll,
      orElse: () => albums.first,
    );
    final assets = await album.getAssetListPaged(page: 0, size: 200);
    if (mounted) {
      setState(() {
        _assets = assets;
        _loadingAssets = false;
      });
    }
  }

  Future<void> _selectPhoto(photo_manager.AssetEntity asset) async {
    if (_loadingImage) return;
    setState(() {
      _selectedAsset = asset;
      _loadingImage = true;
      _alignX = 0;
      _alignY = 0;
    });
    final data = await asset.originBytes;
    if (mounted) {
      setState(() {
        _fullImageData = data;
        _loadingImage = false;
      });
    }
  }

  void _onCropRatioChanged(CropRatio ratio) {
    setState(() {
      _selectedCropRatio = ratio;
      _alignX = 0;
      _alignY = 0;
    });
  }

  Future<void> _saveAllPieces() async {
    if (_fullImageData == null || _isSaving) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() => _isSaving = true);
    try {
      final pieces = await ImageSplitService.splitImage(
        imageData: _fullImageData!,
        rows: _selectedPattern.rows,
        cols: _selectedPattern.cols,
        cropRatio: _selectedCropRatio.ratio,
        alignX: _alignX,
        alignY: _alignY,
      );

      for (int i = pieces.length - 1; i >= 0; i--) {
        await ImageGallerySaver.saveImage(pieces[i]);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.splitSavedCount(pieces.length)),
            backgroundColor: const Color(0xFFFF85A2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.saveFailed(e.toString())),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _goBackToPicker() {
    setState(() {
      _selectedAsset = null;
      _fullImageData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedAsset != null) return _buildEditor(context);
    return _buildPicker(context);
  }

  // ── 阶段1：选择照片 ──

  Widget _buildPicker(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F3),
      appBar: AppBar(
        title: Text(l10n.imageSplit,
            style: const TextStyle(
                fontFamily: 'Fredoka', fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1F2937),
      ),
      body: _loadingAssets
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF85A2)))
          : _assets.isEmpty
              ? Center(
                  child: Text(l10n.noPhotosFound,
                      style: const TextStyle(color: Color(0xFF6B7280))))
              : GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: _assets.length,
                  itemBuilder: (context, index) => GestureDetector(
                    onTap: () => _selectPhoto(_assets[index]),
                    child: PhotoThumbnail(asset: _assets[index]),
                  ),
                ),
    );
  }

  // ── 阶段2：编辑器 ──

  Widget _buildEditor(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F3),
      appBar: AppBar(
        title: Text(l10n.imageSplit,
            style: const TextStyle(
                fontFamily: 'Fredoka', fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: _goBackToPicker,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _loadingImage
                  ? const CircularProgressIndicator(color: Color(0xFFFF85A2))
                  : _fullImageData != null
                      ? _buildPreview()
                      : const SizedBox.shrink(),
            ),
          ),
          _buildRatioSelector(),
          const SizedBox(height: 8),
          _buildPatternSelector(),
          const SizedBox(height: 12),
          _buildSaveButton(l10n),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final imgW = _selectedAsset!.width.toDouble();
    final imgH = _selectedAsset!.height.toDouble();
    if (imgW <= 0 || imgH <= 0) return const SizedBox.shrink();

    final displayRatio =
        _selectedCropRatio.ratio ?? (imgW / imgH);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final containerAspect =
              constraints.maxWidth / constraints.maxHeight;
          double displayW, displayH;
          if (displayRatio > containerAspect) {
            displayW = constraints.maxWidth;
            displayH = constraints.maxWidth / displayRatio;
          } else {
            displayH = constraints.maxHeight;
            displayW = constraints.maxHeight * displayRatio;
          }

          return GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _alignX = (_alignX - details.delta.dx * 3 / displayW)
                    .clamp(-1.0, 1.0);
                _alignY = (_alignY - details.delta.dy * 3 / displayH)
                    .clamp(-1.0, 1.0);
              });
            },
            child: SizedBox(
              width: displayW,
              height: displayH,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      _fullImageData!,
                      fit: BoxFit.cover,
                      alignment: Alignment(_alignX, _alignY),
                      gaplessPlayback: true,
                    ),
                    CustomPaint(
                      painter: SplitGridPainter(
                        rows: _selectedPattern.rows,
                        cols: _selectedPattern.cols,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRatioSelector() {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _kRatios.length,
        itemBuilder: (context, index) {
          final ratio = _kRatios[index];
          final isSelected = ratio.label == _selectedCropRatio.label;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => _onCropRatioChanged(ratio),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFF85A2)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFF85A2)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Text(
                  ratio.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF374151),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPatternSelector() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _kPatterns.length,
        itemBuilder: (context, index) {
          final pattern = _kPatterns[index];
          final isSelected = pattern.id == _selectedPattern.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedPattern = pattern),
            child: Container(
              width: 64,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFF85A2) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFF85A2)
                      : const Color(0xFFE5E7EB),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF85A2).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CustomPaint(
                      painter: MiniGridPainter(
                        rows: pattern.rows,
                        cols: pattern.cols,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFFFF85A2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pattern.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSaveButton(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed:
              (_isSaving || _fullImageData == null) ? null : _saveAllPieces,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF85A2),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFFFB3C6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  l10n.splitSaveButton(_selectedPattern.count),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

