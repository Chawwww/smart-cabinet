// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'config/app_constants.dart';
import 'l10n/l10n.dart';  // ← S class only

import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'providers/item_provider.dart';
import 'providers/category_provider.dart';
import 'providers/cabinet_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/search_provider.dart';
import 'services/notification_service.dart';
import 'services/ai_service.dart';
import 'themes/app_theme.dart';

import 'models/item_model.dart';
import 'models/cabinet_model.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/items_screen.dart';
import 'screens/search_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/category_screen.dart';
import 'screens/add_edit_item_screen.dart';
import 'screens/add_edit_category_screen.dart';
import 'screens/add_edit_cabinet_screen.dart';
import 'screens/item_detail_screen.dart';
import 'screens/cabinet_detail_screen.dart';
import 'screens/share_cabinet_screen.dart';
import 'screens/shared_cabinets_screen.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/help_support_screen.dart';
import 'screens/custom_fields_screen.dart';
import 'screens/language_selector_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/medicine_info_screen.dart';
import 'screens/smart_cabinet_control_screen.dart';
import 'screens/workflows_screen.dart';
import 'screens/door_status_screen.dart';
import 'screens/notification_settings_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('📨 Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final prefs = await SharedPreferences.getInstance();

  await NotificationService().initialize();
  AIService().initialize();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(SmartCabinetApp(prefs: prefs));
}

class SmartCabinetApp extends StatelessWidget {
  final SharedPreferences prefs;

  const SmartCabinetApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        ChangeNotifierProvider(create: (_) => LanguageProvider(prefs)),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ItemProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => CabinetProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, languageProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: AppConstants.appName,
            
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,

            // ✅ Use S.delegate from l10n.dart
            locale: languageProvider.locale,
            supportedLocales: S.delegate.supportedLocales,
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            
            localeResolutionCallback: (locale, supportedLocales) {
              for (final supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale?.languageCode) {
                  return supportedLocale;
                }
              }
              return const Locale('en');
            },

            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/home': (context) => const HomeScreen(),
              '/items': (context) => const ItemsScreen(),
              '/search': (context) => const SearchScreen(),
              '/notifications': (context) => const NotificationsScreen(),
              '/menu': (context) => const MenuScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/categories': (context) => const CategoryScreen(),
              '/add-item': (context) => const AddEditItemScreen(),
              '/add-category': (context) => const AddEditCategoryScreen(),
              '/add-cabinet': (context) => const AddEditCabinetScreen(),
              
              '/item-detail': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                if (args is ItemModel) {
                  return ItemDetailScreen(item: args);
                }
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                        SizedBox(height: 16),
                        Text('Item not found'),
                      ],
                    ),
                  ),
                );
              },
              
              '/cabinet-detail': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                if (args is String) {
                  return CabinetDetailScreen(cabinetId: args);
                }
                return const Scaffold(
                  body: Center(child: Text('Cabinet not found')),
                );
              },
              
              '/share-cabinet': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                if (args is Map<String, String>) {
                  return ShareCabinetScreen(
                    cabinetId: args['cabinetId'] ?? '',
                    cabinetName: args['cabinetName'] ?? '',
                  );
                }
                return const Scaffold(
                  body: Center(child: Text('Cabinet not found')),
                );
              },
              
              '/shared-cabinets': (context) => const SharedCabinetsScreen(),
              '/ai-chat': (context) => const AIChatScreen(),
              '/help-support': (context) => const HelpSupportScreen(),
              '/custom-fields': (context) => const CustomFieldsScreen(),
              '/language-selector': (context) => const LanguageSelectorScreen(),
              '/forgot-password': (context) => const ForgotPasswordScreen(),
              '/medicine-info': (context) => const MedicineInfoScreen(),
              '/smart-cabinet-control': (context) => const SmartCabinetControlScreen(),
              '/workflows': (context) => const WorkflowsScreen(),
              '/door-status': (context) => const DoorStatusScreen(),
              '/notification-settings': (context) => const NotificationSettingsScreen(),
            },
          );
        },
      ),
    );
  }
}