import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_puzzle/providers/puzzle_history_provider.dart';
import 'package:live_puzzle/providers/locale_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:live_puzzle/l10n/app_localizations.dart';

/// 设置页面
class SettingsScreen extends ConsumerWidget {
  final bool showBackButton;
  
  const SettingsScreen({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    
    // 确定当前语言显示文本
    String languageText;
    if (currentLocale == null) {
      languageText = '${l10n.languageChinese} / ${l10n.languageEnglish}';
    } else if (currentLocale.languageCode == 'zh') {
      languageText = l10n.languageChinese;
    } else {
      languageText = l10n.languageEnglish;
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F3),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Back Button - 可选
                  if (showBackButton)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 18,
                          color: Color(0xFFFF4D80),
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  if (showBackButton) const SizedBox(width: 16),
                  // Title
                  Text(
                    l10n.settingsTitle,
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 通用设置
                    _buildSectionTitle(l10n.general),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      context,
                      icon: Icons.photo_library,
                      title: l10n.photoQuality,
                      subtitle: l10n.photoQualityHigh,
                      onTap: () {
                        _showQualityDialog(context, l10n);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      context,
                      icon: Icons.language,
                      title: l10n.language,
                      subtitle: languageText,
                      onTap: () {
                        _showLanguageDialog(context, ref, l10n);
                      },
                    ),

                    const SizedBox(height: 32),

                    // 存储管理
                    _buildSectionTitle(l10n.storage),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      context,
                      icon: Icons.history,
                      title: l10n.clearHistory,
                      subtitle: l10n.clearHistoryDesc,
                      trailing: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
                      onTap: () => _showClearHistoryDialog(context, ref, l10n),
                    ),

                    const SizedBox(height: 32),

                    // 关于
                    _buildSectionTitle(l10n.about),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      context,
                      icon: Icons.info_outline,
                      title: l10n.versionInfo,
                      subtitle: l10n.versionNumber,
                      onTap: () {
                        _showAboutDialog(context, l10n);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      context,
                      icon: Icons.share,
                      title: l10n.shareApp,
                      subtitle: l10n.shareAppDesc,
                      onTap: () {
                        Share.share(l10n.shareAppMessage);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      context,
                      icon: Icons.favorite,
                      title: l10n.rateUs,
                      subtitle: l10n.rateUsDesc,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.thanksForSupport)),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9CA3AF),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE0E8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFFF85A2),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFFFF85A2),
                  size: 16,
                ),
          ],
        ),
      ),
    );
  }

  void _showQualityDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          l10n.photoQualityDialogTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildQualityOption(l10n.photoQualityHigh, true),
            _buildQualityOption(l10n.photoQualityMedium, false),
            _buildQualityOption(l10n.photoQualitySaving, false),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Color(0xFFFF85A2)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.settingsSaved)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF85A2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityOption(String label, bool selected) {
    return ListTile(
      title: Text(label),
      leading: Radio<bool>(
        value: true,
        groupValue: selected,
        onChanged: (value) {},
        activeColor: const Color(0xFFFF85A2),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final currentLocale = ref.read(localeProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          l10n.language,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.languageChinese),
              leading: Radio<String>(
                value: 'zh',
                groupValue: currentLocale?.languageCode ?? 'zh',
                onChanged: (value) {
                  ref.read(localeProvider.notifier).setLocale(const Locale('zh'));
                  Navigator.pop(context);
                },
                activeColor: const Color(0xFFFF85A2),
              ),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('zh'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(l10n.languageEnglish),
              leading: Radio<String>(
                value: 'en',
                groupValue: currentLocale?.languageCode ?? 'zh',
                onChanged: (value) {
                  ref.read(localeProvider.notifier).setLocale(const Locale('en'));
                  Navigator.pop(context);
                },
                activeColor: const Color(0xFFFF85A2),
              ),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('en'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.close,
              style: const TextStyle(color: Color(0xFFFF85A2)),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          l10n.clearHistoryDialogTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        content: Text(l10n.clearHistoryDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(puzzleHistoryProvider.notifier).clearAll();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.historyCleared),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(l10n.confirmDelete),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          l10n.aboutDialogTitle,
          style: const TextStyle(
            fontFamily: 'Fredoka',
            fontWeight: FontWeight.w700,
            color: Color(0xFFFF85A2),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.aboutDialogVersion,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.aboutDialogDesc,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.aboutDialogCopyright,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.close,
              style: const TextStyle(color: Color(0xFFFF85A2)),
            ),
          ),
        ],
      ),
    );
  }
}
