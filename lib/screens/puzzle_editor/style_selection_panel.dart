import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// 预设背景色
const List<Color> kPresetBgColors = [
  Colors.black,
  Colors.white,
  Color(0xFFE0E0E0),
  Color(0xFF424242),
  Color(0xFFFFE0E8),
  Color(0xFFFFF3E0),
  Color(0xFFE0F2F1),
  Color(0xFFE3F2FD),
];

/// 样式选择面板（间距 / 圆角 / 背景色）
class StyleSelectionPanel extends StatelessWidget {
  final double spacing;
  final double cornerRadius;
  final Color backgroundColor;
  final ValueChanged<double> onSpacingChanged;
  final ValueChanged<double> onCornerRadiusChanged;
  final ValueChanged<Color> onBackgroundColorChanged;

  const StyleSelectionPanel({
    super.key,
    required this.spacing,
    required this.cornerRadius,
    required this.backgroundColor,
    required this.onSpacingChanged,
    required this.onCornerRadiusChanged,
    required this.onBackgroundColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labelStyle = TextStyle(
      color: Colors.grey.shade600,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ━━━ 间距 ━━━
          _SliderRow(
            label: l10n.spacing,
            value: spacing,
            min: 0,
            max: 0.06,
            divisions: 12,
            displayText: '${(spacing * 100).toStringAsFixed(1)}%',
            labelStyle: labelStyle,
            onChanged: onSpacingChanged,
          ),
          const SizedBox(height: 8),

          // ━━━ 圆角 ━━━
          _SliderRow(
            label: l10n.cornerRadius,
            value: cornerRadius,
            min: 0,
            max: 30,
            divisions: 15,
            displayText: '${cornerRadius.round()}',
            labelStyle: labelStyle,
            onChanged: onCornerRadiusChanged,
          ),
          const SizedBox(height: 12),

          // ━━━ 背景色 ━━━
          Text(l10n.backgroundColor, style: labelStyle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: kPresetBgColors.map((color) {
              final isSelected = backgroundColor == color;
              return GestureDetector(
                onTap: () => onBackgroundColorChanged(color),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFF85A2)
                          : Colors.grey.shade300,
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color:
                                  const Color(0xFFFF85A2).withValues(alpha: 0.35),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// 可复用的滑块行
class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String displayText;
  final TextStyle labelStyle;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayText,
    required this.labelStyle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 42,
          child: Text(label, style: labelStyle),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFFF85A2),
              inactiveTrackColor: Colors.grey.shade200,
              thumbColor: const Color(0xFFFF85A2),
              overlayColor: const Color(0xFFFF85A2).withValues(alpha: 0.15),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            displayText,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
