import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'config/app_constants.dart';
import 'providers/auth_provider.dart';
import 'providers/language_provider.dart';
import 'providers/item_provider.dart';
import 'providers/category_provider.dart';
import 'providers/cabinet_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/workflows_screen.dart';
import 'screens/items_screen.dart';
import 'screens/search_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/smart_cabinet_control_screen.dart';
import 'screens/language_selector_screen.dart';
import 'screens/medicine_info_screen.dart';
import 'themes/app_theme.dart';
import 'services/notification_service.dart';
import 'services/notification_manager.dart';
import 'services/iot_service.dart';
import 'services/auth_service.dart';
import 'services/navigation_service.dart';
import 'l10n/app_localizations.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final NotificationManager notifManager = NotificationManager();
  await notifManager.handleFCMNotification(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Google Sign-In (skip on web)
  if (!kIsWeb) {
    try {
      await AuthService().initGoogleSignIn();
      debugPrint("✅ Google Sign-In initialized");
    } catch (e) {
      debugPrint("⚠️ Google Sign-In initialization error: $e");
    }
  }

  // Initialize Local Notifications
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings();
  const InitializationSettings initializationSettings =
      InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint('Notification tapped: ${response.payload}');
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        NavigationService.navigateTo('/notifications', arguments: payload);
      }
    },
  );

  // Initialize Firebase Messaging (skip on web)
  if (!kIsWeb) {
    try {
      await NotificationService().requestPermissions();
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      
      FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) async {
          debugPrint('📱 Foreground message received');
          final NotificationManager notifManager = NotificationManager();
          await notifManager.handleFCMNotification(message);
        },
      );
      
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      
      String? token = await messaging.getToken();
      debugPrint("🔑 FCM TOKEN = $token");
      await _storeFCMToken(token);
      
    } catch (e) {
      debugPrint("⚠️ FCM initialization error: $e");
    }
  }

  // Initialize SharedPreferences
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  // Initialize IoT Service (skip on web)
  final IoTService iotService = IoTService();
  if (!kIsWeb) {
    try {
      await iotService.initialize();
      debugPrint("✅ IoT Service initialized");
    } catch (e) {
      debugPrint("⚠️ IoT initialization error: $e");
    }
  }

  // Run the app
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider(prefs)),
        ChangeNotifierProvider(create: (_) => ItemProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => CabinetProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        Provider<IoTService>.value(value: iotService),
      ],
      child: const MyApp(),
    ),
  );
}

// Store FCM token in Firestore
Future<void> _storeFCMToken(String? token) async {
  if (token == null) return;
  
  try {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final User? user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      await firestore
          .collection('users')
          .doc(user.uid)
          .set({
            'fcmToken': token,
            'fcmTokenUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      debugPrint('✅ FCM token stored in Firestore for user: ${user.uid}');
    } else {
      debugPrint('⚠️ No user logged in, FCM token not stored');
    }
  } catch (e) {
    debugPrint('⚠️ Failed to store FCM token: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, child) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          
          // Navigation
          navigatorKey: NavigationService.navigatorKey,
          
          // Theme
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          
          // Localization
          locale: languageProvider.locale,
          supportedLocales: LanguageProvider.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          
          // Home Screen
          home: const SplashScreen(),
          
          // Routes
          routes: {
            '/login': (_) => const LoginScreen(),
            '/register': (_) => const RegisterScreen(),
            '/home': (_) => const HomeScreen(),
            '/workflows': (_) => const WorkflowsScreen(),
            '/items': (_) => const ItemsScreen(),
            '/search': (_) => const SearchScreen(),
            '/notifications': (_) => const NotificationsScreen(),
            '/menu': (_) => const MenuScreen(),
            '/ai-chat': (_) => const AIChatScreen(),
            '/profile': (_) => const ProfileScreen(),
            '/cabinet': (_) => const SmartCabinetControlScreen(),
            '/language-selector': (_) => const LanguageSelectorScreen(),
            '/medicine-info': (_) => const MedicineInfoScreen(),
          },
        );
      },
    );
  }
}