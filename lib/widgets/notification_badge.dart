import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:amanak/provider/notification_provider.dart';
import 'package:amanak/screens/notifications_screen.dart';

class NotificationBadge extends StatelessWidget {
  final double size;
  final Color? badgeColor;
  final VoidCallback? onTap;

  const NotificationBadge({
    Key? key,
    this.size = 24.0,
    this.badgeColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final unreadCount = notificationProvider.unreadCount;

        return GestureDetector(
          onTap: onTap ??
              () {
                Navigator.of(context).pushNamed(NotificationsScreen.routeName);
              },
          child: Stack(
            children: [
              SvgPicture.asset(
                "assets/svg/notification.svg",
                height: size,
                width: size,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: badgeColor ?? primaryColor,
                      shape: unreadCount > 9
                          ? BoxShape.rectangle
                          : BoxShape.circle,
                      borderRadius:
                          unreadCount > 9 ? BorderRadius.circular(8) : null,
                    ),
                    constraints: BoxConstraints(
                      minWidth: size * 0.5,
                      minHeight: size * 0.5,
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: size * 0.36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
