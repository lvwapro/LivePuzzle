// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'LivePuzzle';

  @override
  String get home => 'Home';

  @override
  String get settings => 'Settings';

  @override
  String get welcomeBack => 'Welcome Back,';

  @override
  String get readyToCreate => 'Ready to create magic today?';

  @override
  String get createNew => 'CREATE NEW';

  @override
  String get myStudio => 'My Studio';

  @override
  String get viewAll => 'VIEW ALL';

  @override
  String get justNow => 'JUST NOW';

  @override
  String minAgo(int count) {
    return '$count MIN AGO';
  }

  @override
  String hourAgo(int count) {
    return '$count HOUR AGO';
  }

  @override
  String hoursAgo(int count) {
    return '$count HOURS AGO';
  }

  @override
  String dayAgo(int count) {
    return '$count DAY AGO';
  }

  @override
  String daysAgo(int count) {
    return '$count DAYS AGO';
  }

  @override
  String weekAgo(int count) {
    return '$count WEEK AGO';
  }

  @override
  String weeksAgo(int count) {
    return '$count WEEKS AGO';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get general => 'GENERAL';

  @override
  String get photoQuality => 'Photo Quality';

  @override
  String get photoQualityHigh => 'High Quality (2000x2000)';

  @override
  String get photoQualityMedium => 'Medium Quality (1200x1200)';

  @override
  String get photoQualitySaving => 'Save Space (800x800)';

  @override
  String get language => 'Language';

  @override
  String get languageChinese => 'Chinese';

  @override
  String get languageEnglish => 'English';

  @override
  String get storage => 'STORAGE';

  @override
  String get clearHistory => 'Clear History';

  @override
  String get clearHistoryDesc => 'Delete all history records';

  @override
  String get about => 'ABOUT';

  @override
  String get versionInfo => 'Version Info';

  @override
  String get versionNumber => 'v1.0.0';

  @override
  String get shareApp => 'Share App';

  @override
  String get shareAppDesc => 'Recommend to friends';

  @override
  String get rateUs => 'Rate Us';

  @override
  String get rateUsDesc => 'Rate on App Store';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get done => 'Done';

  @override
  String get photoQualityDialogTitle => 'Photo Quality';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get languageFeatureInDev => 'Language settings feature in development';

  @override
  String get thanksForSupport => 'Thanks for your support!';

  @override
  String get clearHistoryDialogTitle => 'Clear History';

  @override
  String get clearHistoryDialogContent =>
      'Are you sure you want to delete all history records? This action cannot be undone.';

  @override
  String get confirmDelete => 'Confirm Delete';

  @override
  String get historyCleared => 'History cleared';

  @override
  String get aboutDialogTitle => 'LivePuzzle';

  @override
  String get aboutDialogVersion => 'Version: v1.0.0';

  @override
  String get aboutDialogDesc => 'A simple and fun Live Photo puzzle app';

  @override
  String get aboutDialogCopyright => '© 2024 LivePuzzle\\nAll rights reserved';

  @override
  String get close => 'Close';

  @override
  String get shareAppMessage =>
      'I found an amazing Live Photo puzzle app! Try LivePuzzle!';

  @override
  String get noHistoryTitle => 'No history records';

  @override
  String get noHistorySubtitle => 'Create your first puzzle!';

  @override
  String get photosDeletedOrUnavailable =>
      'Photos have been deleted or are unavailable';

  @override
  String get completionTitle => 'Creation Complete!';

  @override
  String get completionMessage => 'Live Photo saved to album';

  @override
  String photoCount(int count) {
    return '$count Photos';
  }

  @override
  String get liveFormat => 'LIVE';

  @override
  String get formatLabel => 'Format';

  @override
  String get share => 'Share';

  @override
  String get createNewPuzzle => 'Create New Puzzle';

  @override
  String get shareImageMessage =>
      'I created a Live Photo puzzle with LivePuzzle!';

  @override
  String get shareFailedNoThumbnail => 'Unable to share: thumbnail unavailable';

  @override
  String shareFailed(String error) {
    return 'Share failed: $error';
  }

  @override
  String get editorTitle => 'Editor';

  @override
  String get play => 'Play';

  @override
  String get selectLayout => 'Select Layout';

  @override
  String get aspectRatio => 'Aspect Ratio';

  @override
  String get puzzleLayouts => 'Puzzle';

  @override
  String get longImageLayouts => 'Long Image';

  @override
  String get horizontalStitch => 'Horizontal Stitch';

  @override
  String get verticalStitch => 'Vertical Stitch';

  @override
  String get permissionRequired => 'Permission Required';

  @override
  String get photoPermissionMessage => 'Please allow access to photos';

  @override
  String get grantPermission => 'Grant Permission';

  @override
  String get helloMaker => 'Hello, Maker!';

  @override
  String get newPuzzle => 'New Puzzle';

  @override
  String get inspiration => 'Inspiration';

  @override
  String get pickMoments => 'Pick Moments';

  @override
  String get continueButton => 'Continue';

  @override
  String get playing => 'Playing...';

  @override
  String get livePuzzleTitle => 'LivePuzzle';

  @override
  String get filters => 'Filters';

  @override
  String get stickers => 'Stickers';

  @override
  String get background => 'BG';

  @override
  String selected(int count) {
    return '$count SELECTED';
  }

  @override
  String get loadingMore => 'Loading more in background...';

  @override
  String get all => 'All';

  @override
  String get livePhotos => 'Live Photos';

  @override
  String get recents => 'Recents';

  @override
  String get favorites => 'Favorites';

  @override
  String get videos => 'Videos';

  @override
  String get selfies => 'Selfies';

  @override
  String get live => 'LIVE';

  @override
  String get portrait => 'Portrait';

  @override
  String get longExposure => 'Long Exposure';

  @override
  String get panoramas => 'Panoramas';

  @override
  String get timelapses => 'Time-Lapse';

  @override
  String get sloMo => 'Slo-Mo';

  @override
  String get bursts => 'Bursts';

  @override
  String get screenshots => 'Screenshots';

  @override
  String get allPhotos => 'All Photos';

  @override
  String get exportingLivePhoto => 'Exporting Live Photo';

  @override
  String get preparingFrames => 'Preparing frame data...';

  @override
  String get loadingFrames => 'Loading video frames';

  @override
  String get renderingFrames => 'Rendering frames';

  @override
  String get savingToAlbum => 'Saving to album...';

  @override
  String get templateQuickGrid4 => 'Grid 4';

  @override
  String get templateQuickGrid4Desc => 'Classic 2x2 grid for beautiful moments';

  @override
  String get templateQuickGrid9 => 'Grid 9';

  @override
  String get templateQuickGrid9Desc => 'Most popular social media display';

  @override
  String get templateQuickDouble => 'Side by Side';

  @override
  String get templateQuickDoubleDesc => 'Compare before & after';

  @override
  String get templateCreativeStory => 'Story Triple';

  @override
  String get templateCreativeStoryDesc => 'Tell a complete story with 3 photos';

  @override
  String get templateCreativeFocus => 'Focus View';

  @override
  String get templateCreativeFocusDesc => 'Highlight the main subject';

  @override
  String get templateCreative6Grid => 'Memory Six';

  @override
  String get templateCreative6GridDesc =>
      'Perfectly balanced visual experience';

  @override
  String get templateClassicSingle => 'Single Focus';

  @override
  String get templateClassicSingleDesc => 'Make one photo the star';

  @override
  String get templateClassicDualVertical => 'Top & Bottom';

  @override
  String get templateClassicDualVerticalDesc => 'Perfect for mobile viewing';

  @override
  String get startCreating => 'Start Creating';

  @override
  String get categoryPopular => 'Popular';

  @override
  String get categoryQuick => 'Quick';

  @override
  String get categoryCreative => 'Creative';

  @override
  String get categoryClassic => 'Classic';

  @override
  String get selectFrameTitle => 'Select Frame';

  @override
  String get alreadySetCover => 'Cover Set';

  @override
  String get dragSliderPreview => 'Drag slider to preview in editor';

  @override
  String get setCover => 'Set as Cover';

  @override
  String get resetCover => 'Reset';

  @override
  String get frameSetSuccess => 'Frame set as cover';

  @override
  String get frameSetFailed => 'Failed to capture frame, please try again';

  @override
  String get canvasRatio => 'Canvas Ratio';

  @override
  String get layoutStyle => 'Layout Style';

  @override
  String get puzzleTab => 'Puzzle';

  @override
  String get longImageTab => 'Long Image';

  @override
  String get preparingLayout => 'Preparing layout configuration...';

  @override
  String get hardwareEncoding => 'Hardware encoding...';

  @override
  String get completed => 'Completed!';

  @override
  String get shareTo => 'Share to';

  @override
  String get quickShare => 'Quick Share';

  @override
  String get wechatFriend => 'WeChat';

  @override
  String get wechatMoments => 'Moments';

  @override
  String get douyin => 'Douyin';

  @override
  String get xiaohongshu => 'RedNote';

  @override
  String get savedToAlbum => 'Saved to album';

  @override
  String saveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get shareToWeChat => 'Share my Live Photo puzzle to WeChat';

  @override
  String get shareToMoments => 'Share my Live Photo puzzle to Moments';

  @override
  String get shareToDouyin => 'Share my Live Photo puzzle to Douyin';

  @override
  String get shareToXiaohongshu => 'Share my Live Photo puzzle to RedNote';

  @override
  String get tabAll => 'All';

  @override
  String get tabLivePhotos => 'Live';

  @override
  String get stitchDirection => 'Stitch Direction';

  @override
  String get noLivePhotosFound => 'No Live Photos found';

  @override
  String get noPhotosFound => 'No photos found';

  @override
  String get pleaseAddLivePhotos => 'Please add Live Photos to your album';

  @override
  String get pleaseAddPhotos => 'Please add photos to your album';

  @override
  String horizontalStitchDesc(int count) {
    return '$count photos stitched left to right';
  }

  @override
  String verticalStitchDesc(int count) {
    return '$count photos stitched top to bottom';
  }

  @override
  String get loadingVideoResources => 'Loading video resources...';

  @override
  String get imageSplit => 'Image Split';

  @override
  String splitSaveButton(int count) {
    return 'Save $count pieces to album';
  }

  @override
  String splitSavedCount(int count) {
    return '$count pieces saved to album';
  }

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get privacyPolicyDesc => 'How we protect your data';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get termsOfServiceDesc => 'App usage terms';

  @override
  String get legal => 'LEGAL';

  @override
  String get privacyPolicyContent =>
      'Privacy Policy\n\nEffective Date: 2026-01-01\n\nLivePuzzle (\"we\", \"our\", \"the App\") respects and protects your privacy. This Privacy Policy explains how we handle information when you use our application.\n\n1. Information Collection\n\nThe App does NOT collect, upload, or share any personal data. All photo processing and puzzle creation happens entirely on your device.\n\n2. Photo Library Access\n\nThe App requires access to your photo library solely to:\n- Browse and select photos/Live Photos for puzzle creation\n- Save created puzzles to your photo album\n\nYour photos are processed locally on your device and are never transmitted to any server.\n\n3. Data Storage\n\nPuzzle history and app preferences are stored locally on your device using standard system storage. This data is not synced to any cloud service.\n\n4. Third-Party Services\n\nThe App does not integrate any third-party analytics, advertising, or tracking services.\n\n5. Children\'s Privacy\n\nThe App does not knowingly collect information from children under 13. The App is suitable for all ages as it does not collect any personal information.\n\n6. Changes to This Policy\n\nWe may update this Privacy Policy from time to time. Any changes will be reflected in the App update.\n\n7. Contact Us\n\nIf you have any questions about this Privacy Policy, please contact us through the App Store listing.\n\n© 2026 LivePuzzle. All rights reserved.';

  @override
  String get styleTab => 'Style';

  @override
  String get spacing => 'Spacing';

  @override
  String get cornerRadius => 'Corners';

  @override
  String get backgroundColor => 'Background';

  @override
  String get termsOfServiceContent =>
      'Terms of Service\n\nEffective Date: 2026-01-01\n\nWelcome to LivePuzzle. By downloading, installing, or using this application, you agree to be bound by these Terms of Service.\n\n1. Acceptance of Terms\n\nBy using LivePuzzle, you confirm that you have read, understood, and agree to these terms. If you do not agree, please do not use the App.\n\n2. Description of Service\n\nLivePuzzle is a photo editing application that allows users to:\n- Create Live Photo puzzles from multiple photos\n- Split images into grid pieces\n- Save created content to the device photo library\n\n3. User Content\n\nYou retain all rights to the photos and content you create using the App. The App does not claim ownership of any user-generated content.\n\n4. Acceptable Use\n\nYou agree to use the App only for lawful purposes and in accordance with these terms. You shall not use the App to process content that violates any applicable laws.\n\n5. Intellectual Property\n\nThe App, including its design, features, and code, is protected by intellectual property laws. You may not copy, modify, distribute, or reverse engineer the App.\n\n6. Disclaimer of Warranties\n\nThe App is provided \"as is\" without warranties of any kind. We do not guarantee that the App will be error-free or uninterrupted.\n\n7. Limitation of Liability\n\nTo the maximum extent permitted by law, we shall not be liable for any indirect, incidental, or consequential damages arising from your use of the App.\n\n8. Changes to Terms\n\nWe reserve the right to modify these terms at any time. Continued use of the App after changes constitutes acceptance of the new terms.\n\n9. Governing Law\n\nThese terms shall be governed by the laws of the jurisdiction in which the developer is located.\n\n10. Contact\n\nFor any questions regarding these terms, please contact us through the App Store listing.\n\n© 2026 LivePuzzle. All rights reserved.';
}
