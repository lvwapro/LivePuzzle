// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'LivePuzzle';

  @override
  String get home => '首页';

  @override
  String get discover => '发现';

  @override
  String get settings => '设置';

  @override
  String get welcomeBack => '欢迎回来，';

  @override
  String get readyToCreate => '准备好今天创造魔法了吗？';

  @override
  String get createNew => '开始创作';

  @override
  String get myStudio => '我的工作室';

  @override
  String get viewAll => '查看全部';

  @override
  String get justNow => '刚刚';

  @override
  String minAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String hourAgo(int count) {
    return '$count 小时前';
  }

  @override
  String hoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String dayAgo(int count) {
    return '$count 天前';
  }

  @override
  String daysAgo(int count) {
    return '$count 天前';
  }

  @override
  String weekAgo(int count) {
    return '$count 周前';
  }

  @override
  String weeksAgo(int count) {
    return '$count 周前';
  }

  @override
  String get discoverTitle => '发现';

  @override
  String get discoverSubtitle => '发现更多精彩内容';

  @override
  String get featureInDevelopment => '功能开发中...';

  @override
  String get settingsTitle => '设置';

  @override
  String get general => '通用';

  @override
  String get photoQuality => '照片质量';

  @override
  String get photoQualityHigh => '高质量 (2000x2000)';

  @override
  String get photoQualityMedium => '中等质量 (1200x1200)';

  @override
  String get photoQualitySaving => '节省空间 (800x800)';

  @override
  String get language => '语言';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get storage => '存储';

  @override
  String get clearHistory => '清除历史记录';

  @override
  String get clearHistoryDesc => '删除所有历史记录';

  @override
  String get about => '关于';

  @override
  String get versionInfo => '版本信息';

  @override
  String get versionNumber => 'v1.0.0';

  @override
  String get shareApp => '分享应用';

  @override
  String get shareAppDesc => '推荐给朋友';

  @override
  String get rateUs => '给我们评分';

  @override
  String get rateUsDesc => '在 App Store 评分';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get delete => '删除';

  @override
  String get save => '保存';

  @override
  String get done => '完成';

  @override
  String get photoQualityDialogTitle => '照片质量';

  @override
  String get settingsSaved => '设置已保存';

  @override
  String get languageFeatureInDev => '语言设置功能开发中';

  @override
  String get thanksForSupport => '感谢您的支持！';

  @override
  String get clearHistoryDialogTitle => '清除历史记录';

  @override
  String get clearHistoryDialogContent => '确定要删除所有历史记录吗？此操作无法撤销。';

  @override
  String get confirmDelete => '确定删除';

  @override
  String get historyCleared => '历史记录已清除';

  @override
  String get aboutDialogTitle => 'LivePuzzle';

  @override
  String get aboutDialogVersion => '版本：v1.0.0';

  @override
  String get aboutDialogDesc => '一个简单而有趣的 Live Photo 拼图应用';

  @override
  String get aboutDialogCopyright => '© 2024 LivePuzzle\\n保留所有权利';

  @override
  String get close => '关闭';

  @override
  String get shareAppMessage => '我发现了一个超棒的 Live Photo 拼图应用！快来试试 LivePuzzle 吧！';

  @override
  String get noHistoryTitle => '暂无历史记录';

  @override
  String get noHistorySubtitle => '创建第一个拼图吧！';

  @override
  String get photosDeletedOrUnavailable => '照片已被删除或无法访问';

  @override
  String get completionTitle => '创作完成！';

  @override
  String get completionMessage => 'Live Photo 已保存到相册';

  @override
  String photoCount(int count) {
    return '$count 张照片';
  }

  @override
  String get liveFormat => 'LIVE';

  @override
  String get formatLabel => '格式';

  @override
  String get share => '分享';

  @override
  String get createNewPuzzle => '创建新拼图';

  @override
  String get shareImageMessage => '我用 LivePuzzle 创建了一个 Live Photo 拼图！';

  @override
  String get shareFailedNoThumbnail => '无法分享：缩略图不可用';

  @override
  String shareFailed(String error) {
    return '分享失败：$error';
  }

  @override
  String get editorTitle => '编辑器';

  @override
  String get play => '播放';

  @override
  String get selectLayout => '选择布局';

  @override
  String get aspectRatio => '宽高比';

  @override
  String get puzzleLayouts => '拼图';

  @override
  String get longImageLayouts => '长图';

  @override
  String get horizontalStitch => '横向拼接';

  @override
  String get verticalStitch => '纵向拼接';

  @override
  String get permissionRequired => '需要权限';

  @override
  String get photoPermissionMessage => '请允许访问相册';

  @override
  String get grantPermission => '授予权限';

  @override
  String get helloMaker => '你好，创作者！';

  @override
  String get newPuzzle => '新拼图';

  @override
  String get inspiration => '灵感';

  @override
  String get pickMoments => '选择时刻';

  @override
  String get continueButton => '继续';

  @override
  String get playing => '播放中...';

  @override
  String get livePuzzleTitle => 'LivePuzzle';

  @override
  String get filters => '滤镜';

  @override
  String get stickers => '贴纸';

  @override
  String get background => '背景';

  @override
  String selected(int count) {
    return '$count 已选';
  }

  @override
  String get loadingMore => '正在后台加载更多...';

  @override
  String get all => '全部';

  @override
  String get livePhotos => '实况照片';

  @override
  String get recents => '最近';

  @override
  String get favorites => '收藏';

  @override
  String get videos => '视频';

  @override
  String get selfies => '自拍';

  @override
  String get live => '实况';

  @override
  String get portrait => '人像';

  @override
  String get longExposure => '长曝光';

  @override
  String get panoramas => '全景';

  @override
  String get timelapses => '延时摄影';

  @override
  String get sloMo => '慢动作';

  @override
  String get bursts => '连拍快照';

  @override
  String get screenshots => '屏幕快照';

  @override
  String get allPhotos => '所有照片';

  @override
  String get exportingLivePhoto => '正在导出 Live Photo';

  @override
  String get preparingFrames => '准备帧数据...';

  @override
  String get loadingFrames => '加载视频帧';

  @override
  String get renderingFrames => '渲染帧';

  @override
  String get savingToAlbum => '正在保存到相册...';

  @override
  String get templateQuickGrid4 => '四宫格';

  @override
  String get templateQuickGrid4Desc => '经典2x2网格，记录美好瞬间';

  @override
  String get templateQuickGrid9 => '九宫格';

  @override
  String get templateQuickGrid9Desc => '最受欢迎的朋友圈展示';

  @override
  String get templateQuickDouble => '左右对比';

  @override
  String get templateQuickDoubleDesc => '展示前后对比，记录变化';

  @override
  String get templateCreativeStory => '故事三连';

  @override
  String get templateCreativeStoryDesc => '三张图讲述完整故事';

  @override
  String get templateCreativeFocus => '焦点展示';

  @override
  String get templateCreativeFocusDesc => '主次分明，突出重点';

  @override
  String get templateCreative6Grid => '六格回忆';

  @override
  String get templateCreative6GridDesc => '完美平衡的视觉体验';

  @override
  String get templateClassicSingle => '单图精选';

  @override
  String get templateClassicSingleDesc => '让一张照片成为焦点';

  @override
  String get templateClassicDualVertical => '上下对话';

  @override
  String get templateClassicDualVerticalDesc => '纵向展示，移动端完美';

  @override
  String get startCreating => '开始创作';

  @override
  String get categoryPopular => '热门';

  @override
  String get categoryQuick => '快速';

  @override
  String get categoryCreative => '创意';

  @override
  String get categoryClassic => '经典';
}
