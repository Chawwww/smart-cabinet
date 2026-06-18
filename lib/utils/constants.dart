class Constants {
  Constants._();

  // =====================
  // Animation
  // =====================

  static const Duration shortAnimation =
      Duration(milliseconds: 200);

  static const Duration mediumAnimation =
      Duration(milliseconds: 400);

  static const Duration longAnimation =
      Duration(milliseconds: 600);

  static const Duration pageAnimation =
      Duration(milliseconds: 300);

  // =====================
  // Spacing
  // =====================

  static const double paddingSmall = 8;
  static const double paddingMedium = 16;
  static const double paddingLarge = 24;
  static const double paddingXLarge = 32;

  // =====================
  // Border Radius
  // =====================

  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusXLarge = 24;

  // =====================
  // Font Sizes
  // =====================

  static const double fontSizeSmall = 12;
  static const double fontSizeMedium = 14;
  static const double fontSizeLarge = 16;
  static const double fontSizeXLarge = 20;
  static const double fontSizeXXLarge = 24;

  // =====================
  // Icon Sizes
  // =====================

  static const double iconSizeSmall = 16;
  static const double iconSizeMedium = 24;
  static const double iconSizeLarge = 32;
  static const double iconSizeXLarge = 48;

  // =====================
  // Maximum Lengths
  // =====================

  static const int maxNameLength = 50;
  static const int maxDescriptionLength = 500;
  static const int maxNoteLength = 1000;
  static const int maxTags = 10;

  // =====================
  // Default Values
  // =====================

  static const String defaultUnit = 'pcs';

  static const int defaultLowStockThreshold = 5;

  static const int defaultExpiryReminderDays = 7;

  static const int defaultQuantity = 1;

  static const String defaultItemStatus = 'inside';

  // =====================
  // Search
  // =====================

  static const int maxSearchResults = 20;

  // =====================
  // Dashboard
  // =====================

  static const int recentItemsCount = 10;

  static const int chartDays = 30;

  // =====================
  // Image
  // =====================

  static const int maxImagesPerItem = 5;

  // =====================
  // BLE
  // =====================

  static const Duration bleConnectionTimeout =
      Duration(seconds: 30);

  static const Duration bleScanDuration =
      Duration(seconds: 10);

  // =====================
  // Notification
  // =====================

  static const String notificationChannelId =
      'smart_cabinet_channel';

  static const String expiryChannelId =
      'expiry_channel';

  // =====================
  // Cache Keys
  // =====================

  static const String themeKey = 'theme_mode';

  static const String languageKey = 'language';

  static const String userIdKey = 'user_id';

  static const String sessionKey = 'session_token';

  static const String lastSyncKey = 'last_sync';

  static const String biometricKey =
      'biometric_enabled';

  static const String firstLaunchKey =
      'first_launch';

  // =====================
  // Collection Names
  // =====================

  static const String usersCollection =
      'users';

  static const String itemsCollection =
      'items';

  static const String categoriesCollection =
      'categories';

  static const String cabinetsCollection =
      'cabinets';

  static const String boxesCollection =
      'boxes';

  static const String notificationsCollection =
      'notifications';

  // =====================
  // Firebase Auth Errors
  // =====================

  static const String firebaseUserNotFound =
      'user-not-found';

  static const String firebaseWrongPassword =
      'wrong-password';

  static const String firebaseEmailInUse =
      'email-already-in-use';

  static const String firebaseInvalidEmail =
      'invalid-email';

  static const String firebaseWeakPassword =
      'weak-password';

  static const String firebaseTooManyRequests =
      'too-many-requests';

  static const String firebaseNetworkError =
      'network-request-failed';

  // =====================
  // Item Status
  // =====================

  static const String statusInside = 'inside';

  static const String statusTaken = 'taken';

  static const String statusUsed = 'used';

  static const String statusDamaged = 'damaged';

  // =====================
  // Expiry Status
  // =====================

  static const String expiryNormal = 'normal';

  static const String expirySoon = 'expiring_soon';

  static const String expiryExpired = 'expired';
}