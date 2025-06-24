import 'package:amanak/chatbot.dart';
import 'package:amanak/gaurdian_location.dart';
import 'package:amanak/login_screen.dart';
import 'package:amanak/medicine_detail_screen.dart';
import 'package:amanak/medicine_search_screen.dart';
import 'package:amanak/nearest_hospitals.dart';
import 'package:amanak/notifications/noti_service.dart';
import 'package:amanak/services/medicines_json_service.dart';
import 'package:amanak/signup/choose_role.dart';
import 'package:amanak/signup/signup_screen.dart';
import 'package:amanak/theme/base_theme.dart';
import 'package:amanak/home_screen.dart';
import 'package:amanak/theme/light_theme.dart';
import 'package:amanak/provider/my_provider.dart';
import 'package:amanak/widgets/overlay_button.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'firebase/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'live_tracking.dart';
import 'onboarding_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:amanak/firebase/firebase_manager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:amanak/home/messaging_tab.dart';
import 'package:amanak/provider/fall_detection_provider.dart';

const apiKey = "AIzaSyDLePMB53Q1Nud4ZG8a2XA9UUYuSLCrY6c";

// Global navigator key for app-wide navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background handler for notification taps
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handle notification response here
  print('Notification tapped in background: ${notificationResponse.payload}');

  // Parse the payload
  final payload = notificationResponse.payload;
  if (payload != null) {
    print('Background notification handler initialized');

    // Handle message notifications
    if (payload.startsWith('message:')) {
      final parts = payload.split(':');
      if (parts.length >= 4) {
        // This will be handled when app is launched
        // Navigation will happen in the onDidReceiveBackgroundNotificationResponse handler
      }
    }
  }
}

// Background message handler for Firebase Cloud Messaging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Need to initialize Firebase here for background handling
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print("Handling a background message: ${message.messageId}");

  // You can process the message here or show a notification
  final notiService = NotiService();
  if (!notiService.isInitialized) {
    await notiService.initNotification();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set up background notification handler
  FlutterLocalNotificationsPlugin().initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: notificationTapBackground,
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  // Set up Firebase Messaging background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize notification service
  final notiService = NotiService();
  await notiService.initNotification();

  // Check for any pending notifications
  final authUser = FirebaseAuth.instance.currentUser;
  if (authUser != null) {
    await notiService.checkPendingNotifications();
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Gemini
  Gemini.init(apiKey: apiKey);

  // Initialize the medicines JSON service
  try {
    await MedicinesJsonService().initialize();
    print('Medicines JSON data loaded successfully');
  } catch (e) {
    print('Error initializing medicines data: $e');
  }

  // Check if user is already logged in
  User? currentUser = FirebaseAuth.instance.currentUser;
  print(
      'Current user on app start: ${currentUser?.email ?? 'No user logged in'}');

  // If user is logged in, reschedule all pill notifications
  if (currentUser != null) {
    try {
      await FirebaseManager.rescheduleAllNotifications();
      print('Rescheduled all pill notifications');
    } catch (e) {
      print('Error rescheduling notifications: $e');
    }
  }

  // Check for missed pills on app startup
  try {
    await FirebaseManager.checkForMissedPills();
  } catch (e) {
    print('Error checking for missed pills: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MyProvider()),
        ChangeNotifierProvider(create: (_) => FallDetectionProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  BaseTheme lightTheme = LightTheme();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if user is already logged in
    final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final String initialRoute =
        isLoggedIn ? HomeScreen.routeName : LoginScreen.routeName;

    return ResponsiveSizer(
      builder: (context, orientation, screenType) {
        return MaterialApp(
          navigatorKey: navigatorKey, // Add global navigator key
          theme: lightTheme.themeData,
          debugShowCheckedModeBanner: false,
          initialRoute: initialRoute,
          routes: {
            OnBoardingScreen.routeName: (context) => OnBoardingScreen(),
            LoginScreen.routeName: (context) => LoginScreen(),
            SignupScreen.routeName: (context) => SignupScreen(),
            ChooseRoleScreen.routeName: (context) => ChooseRoleScreen(),
            HomeScreen.routeName: (context) => HomeScreen(),
            ChatBot.routeName: (context) => ChatBot(),
            LiveTracking.routeName: (context) => LiveTracking(),
            NearestHospitals.routeName: (context) => NearestHospitals(),
            MedicineSearchScreen.routeName: (context) => MedicineSearchScreen(),
            MedicineDetailScreen.routeName: (context) => MedicineDetailScreen(),
            MessagingTab.routeName: (context) => MessagingTab(),
          },
          onGenerateRoute: (settings) {
            // Handle deep linking for message notifications
            if (settings.name == '/messaging') {
              // Extract the arguments
              final args = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (context) => MessagingTab(),
                settings: settings,
              );
            }
            return null;
          },
        );
      },
    );
  }
}
