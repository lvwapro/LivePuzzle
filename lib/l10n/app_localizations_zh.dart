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
  String get liveFormat => '实况';

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

  @override
  String get selectFrameTitle => '选择定格帧';

  @override
  String get alreadySetCover => '已设封面';

  @override
  String get dragSliderPreview => '拖动滑块在编辑区实时预览';

  @override
  String get setCover => '设为封面';

  @override
  String get resetCover => '重新设置';

  @override
  String get frameSetSuccess => '已设置为封面';

  @override
  String get frameSetFailed => '截取帧失败，请重试';

  @override
  String get canvasRatio => '画布比例';

  @override
  String get layoutStyle => '布局样式';

  @override
  String get puzzleTab => '拼图';

  @override
  String get longImageTab => '长图拼接';

  @override
  String get preparingLayout => '正在准备布局配置...';

  @override
  String get hardwareEncoding => '正在硬件编码合成...';

  @override
  String get completed => '完成！';

  @override
  String get shareTo => '分享到';

  @override
  String get quickShare => '闪传相册';

  @override
  String get wechatFriend => '微信好友';

  @override
  String get wechatMoments => '朋友圈';

  @override
  String get douyin => '抖音';

  @override
  String get xiaohongshu => '小红书';

  @override
  String get savedToAlbum => '已保存到相册';

  @override
  String saveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get shareToWeChat => '分享我的 Live Photo 拼图到微信';

  @override
  String get shareToMoments => '分享我的 Live Photo 拼图到朋友圈';

  @override
  String get shareToDouyin => '分享我的 Live Photo 拼图到抖音';

  @override
  String get shareToXiaohongshu => '分享我的 Live Photo 拼图到小红书';

  @override
  String get tabAll => '全部';

  @override
  String get tabLivePhotos => '实况';

  @override
  String get stitchDirection => '拼接方向';

  @override
  String get noLivePhotosFound => '没有找到实况照片';

  @override
  String get noPhotosFound => '没有找到照片';

  @override
  String get pleaseAddLivePhotos => '请在相册中添加实况照片';

  @override
  String get pleaseAddPhotos => '请确保相册中有照片';

  @override
  String horizontalStitchDesc(int count) {
    return '$count张图片从左到右拼接';
  }

  @override
  String verticalStitchDesc(int count) {
    return '$count张图片从上到下拼接';
  }

  @override
  String get loadingVideoResources => '正在加载视频资源...';

  @override
  String get imageSplit => '切图';

  @override
  String splitSaveButton(int count) {
    return '保存 $count 张到相册';
  }

  @override
  String splitSavedCount(int count) {
    return '$count 张切图已保存到相册';
  }

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get privacyPolicyDesc => '了解我们如何保护您的数据';

  @override
  String get termsOfService => '用户协议';

  @override
  String get termsOfServiceDesc => '应用使用条款';

  @override
  String get legal => '法律条款';

  @override
  String get privacyPolicyContent =>
      '隐私政策\n\n生效日期：2026年1月1日\n\nLivePuzzle（以下简称「我们」、「本应用」）尊重并保护您的隐私。本隐私政策说明了您使用本应用时我们如何处理相关信息。\n\n一、信息收集\n\n本应用不会收集、上传或共享任何个人数据。所有照片处理和拼图创建均在您的设备上本地完成。\n\n二、相册访问\n\n本应用需要访问您的相册，仅用于：\n- 浏览和选择照片/实况照片用于拼图创作\n- 将创建的拼图保存到您的相册\n\n您的照片仅在设备本地处理，不会传输到任何服务器。\n\n三、数据存储\n\n拼图历史记录和应用偏好设置使用系统标准存储方式保存在您的设备本地，不会同步到任何云服务。\n\n四、第三方服务\n\n本应用不集成任何第三方分析、广告或跟踪服务。\n\n五、儿童隐私\n\n本应用不会有意收集13岁以下儿童的信息。由于本应用不收集任何个人信息，因此适合所有年龄段使用。\n\n六、政策变更\n\n我们可能会不时更新本隐私政策。任何变更将在应用更新中体现。\n\n七、联系我们\n\n如果您对本隐私政策有任何疑问，请通过 App Store 应用页面联系我们。\n\n© 2026 LivePuzzle 保留所有权利。';

  @override
  String get termsOfServiceContent =>
      '用户协议\n\n生效日期：2026年1月1日\n\n欢迎使用 LivePuzzle。下载、安装或使用本应用即表示您同意受本用户协议的约束。\n\n一、条款接受\n\n使用 LivePuzzle 即表示您已阅读、理解并同意本协议。如果您不同意，请勿使用本应用。\n\n二、服务说明\n\nLivePuzzle 是一款照片编辑应用，允许用户：\n- 使用多张照片创建实况照片拼图\n- 将图片切割成网格切片\n- 将创建的内容保存到设备相册\n\n三、用户内容\n\n您保留使用本应用创建的照片和内容的所有权利。本应用不主张对任何用户生成内容的所有权。\n\n四、合理使用\n\n您同意仅出于合法目的并按照本协议使用本应用。您不得使用本应用处理违反任何适用法律的内容。\n\n五、知识产权\n\n本应用（包括其设计、功能和代码）受知识产权法保护。您不得复制、修改、分发或逆向工程本应用。\n\n六、免责声明\n\n本应用按「原样」提供，不提供任何形式的保证。我们不保证本应用不会出错或不会中断。\n\n七、责任限制\n\n在法律允许的最大范围内，我们不对因您使用本应用而产生的任何间接、附带或后果性损害承担责任。\n\n八、条款变更\n\n我们保留随时修改本协议的权利。在变更后继续使用本应用即表示接受新条款。\n\n九、适用法律\n\n本协议受开发者所在司法管辖区的法律管辖。\n\n十、联系方式\n\n如对本协议有任何疑问，请通过 App Store 应用页面联系我们。\n\n© 2026 LivePuzzle 保留所有权利。';
}
