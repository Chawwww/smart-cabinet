import 'package:flutter/material.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = 
      GlobalKey<NavigatorState>();

  static Future<dynamic> navigateTo(String routeName, {dynamic arguments}) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      throw Exception('Navigator context is not available');
    }
    return Navigator.pushNamed(context, routeName, arguments: arguments);
  }

  static void goBack() {
    final context = navigatorKey.currentContext;
    if (context != null && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  static Future<dynamic> pushReplacement(String routeName, {dynamic arguments}) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      throw Exception('Navigator context is not available');
    }
    return Navigator.pushReplacementNamed(context, routeName, arguments: arguments);
  }

  static Future<dynamic> pushAndRemoveUntil(String routeName, {dynamic arguments}) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      throw Exception('Navigator context is not available');
    }
    return Navigator.pushNamedAndRemoveUntil(
      context, 
      routeName, 
      (route) => false,
      arguments: arguments,
    );
  }
}