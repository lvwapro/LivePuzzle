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
  String get discover => 'Discover';

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
  String get discoverTitle => 'Discover';

  @override
  String get discoverSubtitle => 'Discover more exciting content';

  @override
  String get featureInDevelopment => 'Feature in development...';

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
}
