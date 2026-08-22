// lib/config/app_constants.dart

class AppConstants {
  // =========================
  // App Info
  // =========================
  static const String appName = "Smart Cabinet Finder";

  // =========================
  // Firestore Collections
  // =========================
  static const String usersCollection = "users";
  static const String categoriesCollection = "categories";
  static const String cabinetsCollection = "cabinets";
  static const String boxesCollection = "boxes";
  static const String itemsCollection = "items";
  static const String itemHistoryCollection = "item_history";
  static const String doorLogsCollection = "door_logs";
  static const String notificationsCollection = "notifications";

  // =========================
  // Auth
  // =========================
  static const String sessionKey = 'user_session';
  static const String rememberMeKey = 'remember_me';
  static const String lastEmailKey = 'last_email';
  static const String authTokenKey = 'auth_token';
  static const Duration authTimeout = Duration(seconds: 30);
  static const Duration authThrottleDuration = Duration(minutes: 5);

  // =========================
  // Auth Error Messages
  // =========================
  static const String authErrorDefault =
      'Authentication failed. Please try again.';
  static const String authErrorNetwork =
      'Network error. Please check your connection.';
  static const String authErrorTooManyRequests =
      'Too many attempts. Please try again later.';
  static const String authErrorInvalidEmail = 'Invalid email address.';
  static const String authErrorWeakPassword =
      'Password must be at least 6 characters.';
  static const String authErrorEmailInUse = 'This email is already registered.';
  static const String authErrorUserNotFound =
      'No account found with this email.';
  static const String authErrorWrongPassword = 'Incorrect password.';

  // =========================
  // BLE UUIDs (ESP32) — 2 DOOR VERSION
  // =========================
  static const String bleServiceUUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";

  static const String upperDoorSensorCharacteristic =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String upperServoCharacteristic =
      "beb5483e-36e1-4688-b7f5-ea07361b26a9";
  static const String upperLedCharacteristic =
      "beb5483e-36e1-4688-b7f5-ea07361b26aa";

  static const String lowerDoorSensorCharacteristic =
      "beb5483e-36e1-4688-b7f5-ea07361b26ab";
  static const String lowerServoCharacteristic =
      "beb5483e-36e1-4688-b7f5-ea07361b26ac";
  static const String lowerLedCharacteristic =
      "beb5483e-36e1-4688-b7f5-ea07361b26ad";

  static const String doorUpper = "upper";
  static const String doorLower = "lower";

  // =========================
  // MQTT
  // =========================
  static const String mqttServer = "broker.hivemq.com";
  static const int mqttPort = 1883;

  static const String mqttDoorTopicUpper = "smart_cabinet/door/upper";
  static const String mqttDoorTopicLower = "smart_cabinet/door/lower";
  static const String mqttLedTopicUpper = "smart_cabinet/led/upper";
  static const String mqttLedTopicLower = "smart_cabinet/led/lower";
  static const String mqttServoTopicUpper = "smart_cabinet/servo/upper";
  static const String mqttServoTopicLower = "smart_cabinet/servo/lower";

  // =========================
  // Gemini AI
  // =========================
  // Supply at build/run time with:
  // --dart-define=GEMINI_API_KEY=your_key
  // Do not commit credentials to the repository.
  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  // =========================
  // Item Status
  // =========================
  static const String statusNormal = "normal";
  static const String statusExpiringSoon = "expiring_soon";
  static const String statusExpired = "expired";

  static const String itemInside = "inside";
  static const String itemTaken = "taken";
  static const String itemUsed = "used";
  static const String itemDamaged = "damaged";

  // =========================
  // Notification Types
  // =========================
  static const String notificationExpiry = "expiry";
  static const String notificationLowStock = "low_stock";
  static const String notificationDoorOpen = "door_open";
  static const String notificationReminder = "reminder";

  // =========================
  // Route Names
  // =========================
  static const String routeLogin = "/login";
  static const String routeRegister = "/register";
  static const String routeHome = "/home";
  static const String routeItems = "/items";
  static const String routeSearch = "/search";
  static const String routeProfile = "/profile";
  static const String routeNotifications = "/notifications";
  static const String routeWorkflows = "/workflows";
  static const String routeMenu = "/menu";
  static const String routeAiChat = "/ai-chat";
  static const String routeCabinet = "/cabinet";

  // =========================
  // Shared Preferences Keys
  // =========================
  static const String themeKey = "theme_mode";
  static const String userIdKey = "user_id";
  static const String firstLaunchKey = "first_launch";

  // =========================
  // Default Categories
  // =========================
  static const List<Map<String, dynamic>> defaultCategories = [
    {"name": "Medicine", "icon": "💊", "color": "#FF6B6B"},
    {"name": "Food", "icon": "🍕", "color": "#FFA94D"},
    {"name": "Drinks", "icon": "🥤", "color": "#4ECDC4"},
    {"name": "Tools", "icon": "🔧", "color": "#45B7D1"},
    {"name": "Documents", "icon": "📄", "color": "#96CEB4"},
    {"name": "Others", "icon": "📦", "color": "#DDA0DD"},
  ];
}
