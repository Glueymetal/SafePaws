import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // 🎯 ADD THIS
import 'package:pawsafe/screens/home_screen.dart';
import 'package:pawsafe/services/analytics_service.dart'; // 🎯 ADD THIS
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔐 IMPORTANT: Anonymous authentication (REQUIRED for Firestore rules)
  await FirebaseAuth.instance.signInAnonymously();

  // 🎯 Initialize Analytics
  final analytics = AnalyticsService();
  await analytics.logEvent(name: 'app_opened');

  runApp(MyApp(analytics: analytics));
}

class MyApp extends StatelessWidget {
  final AnalyticsService analytics; // 🎯 ADD THIS

  const MyApp({super.key, required this.analytics}); // 🎯 UPDATED

  @override
  Widget build(BuildContext context) {
    return Provider<AnalyticsService>.value(
      // 🎯 WRAP WITH PROVIDER
      value: analytics,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Safe Paws',
        // 🎯 ADD ANALYTICS OBSERVER
        navigatorObservers: [
          analytics.getAnalyticsObserver(),
        ],
        home: HomeScreen(),
      ),
    );
  }
}
