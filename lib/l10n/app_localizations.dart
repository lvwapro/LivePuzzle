import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// 应用名称 - The application name
  ///
  /// In en, this message translates to:
  /// **'LivePuzzle'**
  String get appName;

  /// 主页
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// 设置
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// 欢迎回来
  ///
  /// In en, this message translates to:
  /// **'Welcome Back,'**
  String get welcomeBack;

  /// 准备创作
  ///
  /// In en, this message translates to:
  /// **'Ready to create magic today?'**
  String get readyToCreate;

  /// 开始创作
  ///
  /// In en, this message translates to:
  /// **'CREATE NEW'**
  String get createNew;

  /// 我的工作室
  ///
  /// In en, this message translates to:
  /// **'My Studio'**
  String get myStudio;

  /// 查看全部
  ///
  /// In en, this message translates to:
  /// **'VIEW ALL'**
  String get viewAll;

  /// 刚刚
  ///
  /// In en, this message translates to:
  /// **'JUST NOW'**
  String get justNow;

  /// 分钟前
  ///
  /// In en, this message translates to:
  /// **'{count} MIN AGO'**
  String minAgo(int count);

  /// 小时前
  ///
  /// In en, this message translates to:
  /// **'{count} HOUR AGO'**
  String hourAgo(int count);

  /// 多小时前
  ///
  /// In en, this message translates to:
  /// **'{count} HOURS AGO'**
  String hoursAgo(int count);

  /// 天前
  ///
  /// In en, this message translates to:
  /// **'{count} DAY AGO'**
  String dayAgo(int count);

  /// 多天前
  ///
  /// In en, this message translates to:
  /// **'{count} DAYS AGO'**
  String daysAgo(int count);

  /// 周前
  ///
  /// In en, this message translates to:
  /// **'{count} WEEK AGO'**
  String weekAgo(int count);

  /// 多周前
  ///
  /// In en, this message translates to:
  /// **'{count} WEEKS AGO'**
  String weeksAgo(int count);

  /// 设置标题
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// 通用
  ///
  /// In en, this message translates to:
  /// **'GENERAL'**
  String get general;

  /// 照片质量
  ///
  /// In en, this message translates to:
  /// **'Photo Quality'**
  String get photoQuality;

  /// 高质量
  ///
  /// In en, this message translates to:
  /// **'High Quality (2000x2000)'**
  String get photoQualityHigh;

  /// 中等质量
  ///
  /// In en, this message translates to:
  /// **'Medium Quality (1200x1200)'**
  String get photoQualityMedium;

  /// 节省空间
  ///
  /// In en, this message translates to:
  /// **'Save Space (800x800)'**
  String get photoQualitySaving;

  /// 语言
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// 简体中文
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageChinese;

  /// 英语
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// 存储
  ///
  /// In en, this message translates to:
  /// **'STORAGE'**
  String get storage;

  /// 清除历史记录
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistory;

  /// 清除历史记录描述
  ///
  /// In en, this message translates to:
  /// **'Delete all history records'**
  String get clearHistoryDesc;

  /// 关于
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get about;

  /// 版本信息
  ///
  /// In en, this message translates to:
  /// **'Version Info'**
  String get versionInfo;

  /// 版本号
  ///
  /// In en, this message translates to:
  /// **'v1.0.0'**
  String get versionNumber;

  /// 分享应用
  ///
  /// In en, this message translates to:
  /// **'Share App'**
  String get shareApp;

  /// 分享应用描述
  ///
  /// In en, this message translates to:
  /// **'Recommend to friends'**
  String get shareAppDesc;

  /// 给我们评分
  ///
  /// In en, this message translates to:
  /// **'Rate Us'**
  String get rateUs;

  /// 评分描述
  ///
  /// In en, this message translates to:
  /// **'Rate on App Store'**
  String get rateUsDesc;

  /// 取消
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// 确定
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// 删除
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// 保存
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// 完成
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// 照片质量对话框标题
  ///
  /// In en, this message translates to:
  /// **'Photo Quality'**
  String get photoQualityDialogTitle;

  /// 设置已保存
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// 语言功能开发中
  ///
  /// In en, this message translates to:
  /// **'Language settings feature in development'**
  String get languageFeatureInDev;

  /// 感谢支持
  ///
  /// In en, this message translates to:
  /// **'Thanks for your support!'**
  String get thanksForSupport;

  /// 清除历史对话框标题
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistoryDialogTitle;

  /// 清除历史对话框内容
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all history records? This action cannot be undone.'**
  String get clearHistoryDialogContent;

  /// 确定删除
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get confirmDelete;

  /// 历史已清除
  ///
  /// In en, this message translates to:
  /// **'History cleared'**
  String get historyCleared;

  /// 关于对话框标题
  ///
  /// In en, this message translates to:
  /// **'LivePuzzle'**
  String get aboutDialogTitle;

  /// 关于对话框版本
  ///
  /// In en, this message translates to:
  /// **'Version: v1.0.0'**
  String get aboutDialogVersion;

  /// 关于对话框描述
  ///
  /// In en, this message translates to:
  /// **'A simple and fun Live Photo puzzle app'**
  String get aboutDialogDesc;

  /// 关于对话框版权
  ///
  /// In en, this message translates to:
  /// **'© 2024 LivePuzzle\\nAll rights reserved'**
  String get aboutDialogCopyright;

  /// 关闭
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// 分享应用消息
  ///
  /// In en, this message translates to:
  /// **'I found an amazing Live Photo puzzle app! Try LivePuzzle!'**
  String get shareAppMessage;

  /// 暂无历史
  ///
  /// In en, this message translates to:
  /// **'No history records'**
  String get noHistoryTitle;

  /// 暂无历史副标题
  ///
  /// In en, this message translates to:
  /// **'Create your first puzzle!'**
  String get noHistorySubtitle;

  /// 照片不可用
  ///
  /// In en, this message translates to:
  /// **'Photos have been deleted or are unavailable'**
  String get photosDeletedOrUnavailable;

  /// 创作完成
  ///
  /// In en, this message translates to:
  /// **'Creation Complete!'**
  String get completionTitle;

  /// 保存成功
  ///
  /// In en, this message translates to:
  /// **'Live Photo saved to album'**
  String get completionMessage;

  /// 照片数量
  ///
  /// In en, this message translates to:
  /// **'{count} Photos'**
  String photoCount(int count);

  /// 实况格式
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get liveFormat;

  /// 格式
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get formatLabel;

  /// 分享
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// 创建新拼图
  ///
  /// In en, this message translates to:
  /// **'Create New Puzzle'**
  String get createNewPuzzle;

  /// 分享图片消息
  ///
  /// In en, this message translates to:
  /// **'I created a Live Photo puzzle with LivePuzzle!'**
  String get shareImageMessage;

  /// 无法分享缩略图
  ///
  /// In en, this message translates to:
  /// **'Unable to share: thumbnail unavailable'**
  String get shareFailedNoThumbnail;

  /// 分享失败
  ///
  /// In en, this message translates to:
  /// **'Share failed: {error}'**
  String shareFailed(String error);

  /// 编辑器
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get editorTitle;

  /// 播放
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// 选择布局
  ///
  /// In en, this message translates to:
  /// **'Select Layout'**
  String get selectLayout;

  /// 宽高比
  ///
  /// In en, this message translates to:
  /// **'Aspect Ratio'**
  String get aspectRatio;

  /// 拼图布局
  ///
  /// In en, this message translates to:
  /// **'Puzzle'**
  String get puzzleLayouts;

  /// 长图布局
  ///
  /// In en, this message translates to:
  /// **'Long Image'**
  String get longImageLayouts;

  /// 横向拼接
  ///
  /// In en, this message translates to:
  /// **'Horizontal Stitch'**
  String get horizontalStitch;

  /// 纵向拼接
  ///
  /// In en, this message translates to:
  /// **'Vertical Stitch'**
  String get verticalStitch;

  /// 需要权限
  ///
  /// In en, this message translates to:
  /// **'Permission Required'**
  String get permissionRequired;

  /// 照片权限
  ///
  /// In en, this message translates to:
  /// **'Please allow access to photos'**
  String get photoPermissionMessage;

  /// 授予权限
  ///
  /// In en, this message translates to:
  /// **'Grant Permission'**
  String get grantPermission;

  /// 你好，创作者
  ///
  /// In en, this message translates to:
  /// **'Hello, Maker!'**
  String get helloMaker;

  /// 新拼图
  ///
  /// In en, this message translates to:
  /// **'New Puzzle'**
  String get newPuzzle;

  /// 灵感
  ///
  /// In en, this message translates to:
  /// **'Inspiration'**
  String get inspiration;

  /// 选择时刻
  ///
  /// In en, this message translates to:
  /// **'Pick Moments'**
  String get pickMoments;

  /// 继续
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// 播放中
  ///
  /// In en, this message translates to:
  /// **'Playing...'**
  String get playing;

  /// LivePuzzle标题
  ///
  /// In en, this message translates to:
  /// **'LivePuzzle'**
  String get livePuzzleTitle;

  /// 滤镜
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// 贴纸
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get stickers;

  /// 背景
  ///
  /// In en, this message translates to:
  /// **'BG'**
  String get background;

  /// 已选数量
  ///
  /// In en, this message translates to:
  /// **'{count} SELECTED'**
  String selected(int count);

  /// 正在后台加载更多
  ///
  /// In en, this message translates to:
  /// **'Loading more in background...'**
  String get loadingMore;

  /// 全部
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// 实况照片
  ///
  /// In en, this message translates to:
  /// **'Live Photos'**
  String get livePhotos;

  /// 最近
  ///
  /// In en, this message translates to:
  /// **'Recents'**
  String get recents;

  /// 收藏
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// 视频
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get videos;

  /// 自拍
  ///
  /// In en, this message translates to:
  /// **'Selfies'**
  String get selfies;

  /// 实况/LIVE
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get live;

  /// 人像
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get portrait;

  /// 长曝光
  ///
  /// In en, this message translates to:
  /// **'Long Exposure'**
  String get longExposure;

  /// 全景
  ///
  /// In en, this message translates to:
  /// **'Panoramas'**
  String get panoramas;

  /// 延时摄影
  ///
  /// In en, this message translates to:
  /// **'Time-Lapse'**
  String get timelapses;

  /// 慢动作
  ///
  /// In en, this message translates to:
  /// **'Slo-Mo'**
  String get sloMo;

  /// 连拍快照
  ///
  /// In en, this message translates to:
  /// **'Bursts'**
  String get bursts;

  /// 屏幕快照
  ///
  /// In en, this message translates to:
  /// **'Screenshots'**
  String get screenshots;

  /// 所有照片
  ///
  /// In en, this message translates to:
  /// **'All Photos'**
  String get allPhotos;

  /// 导出进度 - 主标题
  ///
  /// In en, this message translates to:
  /// **'Exporting Live Photo'**
  String get exportingLivePhoto;

  /// 导出进度 - 准备阶段
  ///
  /// In en, this message translates to:
  /// **'Preparing frames...'**
  String get preparingFrames;

  /// 导出进度 - 加载帧
  ///
  /// In en, this message translates to:
  /// **'Loading video frames'**
  String get loadingFrames;

  /// 导出进度 - 渲染帧
  ///
  /// In en, this message translates to:
  /// **'Rendering frames'**
  String get renderingFrames;

  /// 导出进度 - 保存阶段
  ///
  /// In en, this message translates to:
  /// **'Saving to album...'**
  String get savingToAlbum;

  /// 快速创建 - 四宫格模板名称
  ///
  /// In en, this message translates to:
  /// **'Grid 4'**
  String get templateQuickGrid4;

  /// 四宫格模板描述
  ///
  /// In en, this message translates to:
  /// **'Classic 2x2 grid for beautiful moments'**
  String get templateQuickGrid4Desc;

  /// 快速创建 - 九宫格模板名称
  ///
  /// In en, this message translates to:
  /// **'Grid 9'**
  String get templateQuickGrid9;

  /// 九宫格模板描述
  ///
  /// In en, this message translates to:
  /// **'Most popular social media display'**
  String get templateQuickGrid9Desc;

  /// 快速创建 - 左右对比模板名称
  ///
  /// In en, this message translates to:
  /// **'Side by Side'**
  String get templateQuickDouble;

  /// 左右对比模板描述
  ///
  /// In en, this message translates to:
  /// **'Compare before & after'**
  String get templateQuickDoubleDesc;

  /// 创意布局 - 故事三连模板名称
  ///
  /// In en, this message translates to:
  /// **'Story Triple'**
  String get templateCreativeStory;

  /// 故事三连模板描述
  ///
  /// In en, this message translates to:
  /// **'Tell a complete story with 3 photos'**
  String get templateCreativeStoryDesc;

  /// 创意布局 - 焦点展示模板名称
  ///
  /// In en, this message translates to:
  /// **'Focus View'**
  String get templateCreativeFocus;

  /// 焦点展示模板描述
  ///
  /// In en, this message translates to:
  /// **'Highlight the main subject'**
  String get templateCreativeFocusDesc;

  /// 创意布局 - 六格回忆模板名称
  ///
  /// In en, this message translates to:
  /// **'Memory Six'**
  String get templateCreative6Grid;

  /// 六格回忆模板描述
  ///
  /// In en, this message translates to:
  /// **'Perfectly balanced visual experience'**
  String get templateCreative6GridDesc;

  /// 经典布局 - 单图精选模板名称
  ///
  /// In en, this message translates to:
  /// **'Single Focus'**
  String get templateClassicSingle;

  /// 单图精选模板描述
  ///
  /// In en, this message translates to:
  /// **'Make one photo the star'**
  String get templateClassicSingleDesc;

  /// 经典布局 - 上下对话模板名称
  ///
  /// In en, this message translates to:
  /// **'Top & Bottom'**
  String get templateClassicDualVertical;

  /// 上下对话模板描述
  ///
  /// In en, this message translates to:
  /// **'Perfect for mobile viewing'**
  String get templateClassicDualVerticalDesc;

  /// 开始创作按钮文本
  ///
  /// In en, this message translates to:
  /// **'Start Creating'**
  String get startCreating;

  /// 分类 - 热门
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get categoryPopular;

  /// 分类 - 快速
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get categoryQuick;

  /// 分类 - 创意
  ///
  /// In en, this message translates to:
  /// **'Creative'**
  String get categoryCreative;

  /// 分类 - 经典
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get categoryClassic;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
