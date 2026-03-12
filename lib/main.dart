import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'providers/expense_provider.dart';
import 'providers/theme_provider.dart';
import 'utils/theme.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/add_expense_screen.dart';
import 'screens/add_friend_screen.dart';
import 'screens/add_group_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/activity_feed_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyBbBiwafPzLzdNhXFdrrO3KGpSjJoFXV0Q',
        appId: '1:671680591026:android:29a8b1aca241a5835fc5ab',
        messagingSenderId: '671680591026',
        projectId: 'muneem-ji-f4b29',
        storageBucket: 'muneem-ji-f4b29.firebasestorage.app',
      ),
    );

    // ── FCM Setup ──────────────────────────────────────────────
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    final fcmToken = await messaging.getToken();
    debugPrint('FCM Token: $fcmToken');

    // Foreground notification display
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received FCM: ${message.notification?.title}');
    });
  } catch (e) {
    debugPrint('Firebase not initialized: $e');
  }
  runApp(const MuneemJiApp());
}

class MuneemJiApp extends StatelessWidget {
  const MuneemJiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Muneem Ji',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            // Smart initial routing: check if firebase user is already logged in
            home: const _RootRouter(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/signup': (context) => const SignupScreen(),
              '/dashboard': (context) => DashboardScreen(),
              '/add_expense': (context) => const AddExpenseScreen(),
              '/add_friend': (context) => const AddFriendScreen(),
              '/add_group': (context) => const AddGroupScreen(),
              '/analytics': (context) => const AnalyticsScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/activity': (context) => const ActivityFeedScreen(),
            },
          );
        },
      ),
    );
  }
}

/// Automatically routes to Dashboard if user already logged in, else Login.
class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data != null) {
          return DashboardScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
