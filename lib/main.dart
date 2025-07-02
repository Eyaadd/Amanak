import 'package:amanak/chatbot.dart';
import 'package:amanak/login_screen.dart';
import 'package:amanak/medicine_detail_screen.dart';
import 'package:amanak/medicine_search_screen.dart';
import 'package:amanak/nearest_hospitals.dart';
import 'package:amanak/notifications/noti_service.dart';
import 'package:amanak/services/medicines_json_service.dart';
import 'package:amanak/services/localization_service.dart';
import 'package:amanak/signup/choose_role.dart';
import 'package:amanak/signup/signup_screen.dart';
import 'package:amanak/theme/base_theme.dart';
import 'package:amanak/home_screen.dart';
import 'package:amanak/theme/light_theme.dart';
import 'package:amanak/provider/my_provider.dart';
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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:amanak/screens/language_selection_screen.dart';
import 'package:amanak/home/messaging_tab.dart';
import 'package:amanak/provider/fall_detection_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amanak/provider/notification_provider.dart';
import 'package:amanak/screens/notifications_screen.dart';
import 'package:amanak/gaurdian_location.dart';
import 'package:amanak/screens/simple_splash_screen.dart';

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

  // Remove the always-clear onboarding flag for production
  // final prefs = await SharedPreferences.getInstance();
  // await prefs.remove('onboarding_completed');

  // Set up background notification handler
  FlutterLocalNotificationsPlugin().initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('notification_icon'),
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

  // Initialize localization service
  final localizationService = LocalizationService();
  await localizationService.initialize();

  // Get SharedPreferences instance
  final prefs = await SharedPreferences.getInstance();

  // Check if this is the first launch ever
  final bool isFirstLaunch = !(prefs.containsKey('first_launch_completed'));
  if (isFirstLaunch) {
    // If it's the first launch, reset onboarding and language flags
    await prefs.setBool('first_launch_completed', true);
    await prefs.setBool('language_selected', false);
    await prefs.setBool('onboarding_completed', false);
    print('First app launch detected, resetting onboarding flow');
  } else {
    // If not the first launch, ensure we don't show onboarding screens for returning users
    if (FirebaseAuth.instance.currentUser != null) {
      await prefs.setBool('language_selected', true);
      await prefs.setBool('onboarding_completed', true);
    }
  }

  final bool languageSelected = prefs.getBool('language_selected') ?? false;
  final bool onboardingCompleted =
      prefs.getBool('onboarding_completed') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => MyProvider()),
        ChangeNotifierProvider(create: (context) => localizationService),
        ChangeNotifierProvider(create: (_) => FallDetectionProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MyApp(
        languageSelected: languageSelected,
        onboardingCompleted: onboardingCompleted,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  BaseTheme lightTheme = LightTheme();
  final bool languageSelected;
  final bool onboardingCompleted;

  MyApp({
    required this.languageSelected,
    required this.onboardingCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);

    return ResponsiveSizer(
      builder: (context, orientation, screenType) {
        return MaterialApp(
          navigatorKey: navigatorKey, // Add global navigator key
          theme: lightTheme.themeData,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'), // English
            Locale('ar'), // Arabic
          ],
          locale: localizationService.currentLocale,
          // Use the simple splash screen as the home widget
          home: const SimpleSplashScreen(),
          routes: {
            HomeScreen.routeName: (_) => HomeScreen(),
            MedicineSearchScreen.routeName: (_) => MedicineSearchScreen(),
            MedicineDetailScreen.routeName: (_) => MedicineDetailScreen(),
            LiveTracking.routeName: (_) => LiveTracking(),
            NearestHospitals.routeName: (_) => NearestHospitals(),
            LoginScreen.routeName: (_) => LoginScreen(),
            OnBoardingScreen.routeName: (_) => OnBoardingScreen(),
            LanguageSelectionScreen.routeName: (_) => LanguageSelectionScreen(),
            SignupScreen.routeName: (_) => SignupScreen(),
            ChooseRoleScreen.routeName: (_) => ChooseRoleScreen(),
            ChatBot.routeName: (_) => ChatBot(),
            GuardianLiveTracking.routeName: (_) => GuardianLiveTracking(),
            NotificationsScreen.routeName: (_) => NotificationsScreen(),
          },
          onGenerateRoute: (settings) {
            // Handle deep linking for message notifications
            if (settings.name == '/messaging') {
              // Extract arguments
              final args = settings.arguments as Map<String, dynamic>?;
              if (args != null) {
                final chatId = args['chatId'] as String?;
                final senderId = args['senderId'] as String?;
                final senderName = args['senderName'] as String?;

                if (chatId != null && senderId != null) {
                  return MaterialPageRoute(
                    builder: (context) => MessagingTab(),
                    settings: settings,
                  );
                }
              }
            }
            return null;
          },
        );
      },
    );
  }
}
