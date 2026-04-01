import 'package:live_puzzle/l10n/app_localizations.dart';

/// 翻译系统相册名称
String translateAlbumName(AppLocalizations l10n, String name) {
  switch (name.toLowerCase()) {
    case 'recents':
    case '最近项目':
    case '最近':
      return l10n.recents;
    case 'favorites':
    case '个人收藏':
    case '收藏':
      return l10n.favorites;
    case 'videos':
    case '视频':
      return l10n.videos;
    case 'selfies':
    case '自拍':
      return l10n.selfies;
    case 'live photos':
    case '实况照片':
      return l10n.livePhotos;
    case 'portrait':
    case 'portraits':
    case '人像':
      return l10n.portrait;
    case 'long exposure':
    case '长曝光':
      return l10n.longExposure;
    case 'panoramas':
    case '全景':
      return l10n.panoramas;
    case 'time-lapse':
    case 'timelapses':
    case '延时摄影':
      return l10n.timelapses;
    case 'slo-mo':
    case 'slomo':
    case '慢动作':
      return l10n.sloMo;
    case 'bursts':
    case '连拍快照':
      return l10n.bursts;
    case 'screenshots':
    case '屏幕快照':
      return l10n.screenshots;
    case 'all photos':
    case '所有照片':
      return l10n.allPhotos;
    default:
      return name;
  }
}
