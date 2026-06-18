import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

import 'config/app_constants.dart';

import 'providers/auth_provider.dart';
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

import 'themes/app_theme.dart';

import 'services/notification_service.dart';
import 'services/iot_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService().showLocalNotification(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Local notifications
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
      debugPrint(
        'Notification tapped: ${response.payload}',
      );
    },
  );

  // Firebase Messaging (mobile only)
  if (!kIsWeb) {
    try {
      await NotificationService().requestPermissions();

      final FirebaseMessaging messaging =
          FirebaseMessaging.instance;

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) async {
          await NotificationService()
              .showLocalNotification(message);
        },
      );

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      String? token = await messaging.getToken();

      debugPrint("FCM TOKEN = $token");
    } catch (e) {
      debugPrint("FCM initialization error: $e");
    }
  }

  // Shared Preferences
  final SharedPreferences prefs =
      await SharedPreferences.getInstance();

  // IoT Service
  final IoTService iotService = IoTService();

  if (!kIsWeb) {
    try {
      await iotService.initialize();
      debugPrint("IoT Service initialized");
    } catch (e) {
      debugPrint("IoT initialization error: $e");
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ItemProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => CategoryProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => CabinetProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(prefs),
        ),
        Provider<IoTService>.value(
          value: iotService,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,

          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,

          home: const SplashScreen(),

          routes: {
            '/login': (_) => const LoginScreen(),
            '/register': (_) => const RegisterScreen(),
            '/home': (_) => const HomeScreen(),
            '/workflows': (_) => const WorkflowsScreen(),
            '/items': (_) => const ItemsScreen(),
            '/search': (_) => const SearchScreen(),
            '/notifications': (_) =>
                const NotificationsScreen(),
            '/menu': (_) => const MenuScreen(),
            '/ai-chat': (_) => const AIChatScreen(),
            '/profile': (_) => const ProfileScreen(),
          },
        );
      },
    );
  }
}