// lib/widgets/notification_badge.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/notification_manager.dart';

class NotificationBadge extends StatelessWidget {
  final VoidCallback? onTap;
  final Color? iconColor;

  const NotificationBadge({
    super.key,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().currentUser?.id;
    
    if (userId == null) {
      return IconButton(
        icon: Icon(Icons.notifications_outlined, color: iconColor),
        onPressed: onTap,
      );
    }

    return StreamBuilder<int>(
      stream: NotificationManager().streamUnreadNotificationCount(userId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        
        return Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications_outlined, color: iconColor),
              onPressed: onTap,
            ),
            if (count > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}