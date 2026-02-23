import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import main.dart so we can access the global scaffoldMessengerKey
import '../main.dart'; 

// TOP-LEVEL FUNCTION FOR BACKGROUND MESSAGES
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🔔 Background message received: ${message.notification?.title}");
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initNotifications() async {
    // 1. Check if the user has disabled notifications locally
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('notifications_enabled') ?? true;

    if (!isEnabled) {
      print('Notifications are turned OFF in settings. Skipping init.');
      return; 
    }

    // 2. Request permissions (shows the OS popup)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
      
      // 3. Get the token
      String? token = await _fcm.getToken();
      print('FCM Device Token: $token');

      // 4. Save the token to Supabase
      if (token != null) {
        await _saveTokenToDatabase(token);
      }

      // 5. Listen for token refreshes in the background
      _fcm.onTokenRefresh.listen((newToken) {
        _saveTokenToDatabase(newToken);
      });

      // 6. Initialize listeners for incoming messages and taps
      _setupMessageHandlers();
      
    } else {
      print('User declined or has not accepted permission');
    }
  }

  // --- METHOD TO HANDLE THE ON/OFF TOGGLE ---
  Future<void> toggleNotifications(bool turnOn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', turnOn);

    if (turnOn) {
      // User turned them ON: re-initialize and fetch a new token
      print('✅ Notifications turned ON. Initializing...');
      await initNotifications();
    } else {
      // User turned them OFF: Delete the token from Firebase and Supabase
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await _fcm.deleteToken(); 
        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': null}) 
            .eq('id', userId);
        print('❌ Notifications turned OFF and token deleted.');
      }
    }
  }

  // --- LOGIC TO SAVE TOKEN ---
  Future<void> _saveTokenToDatabase(String token) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      
      if (userId == null) {
        print("User not logged in, cannot save FCM token yet.");
        return;
      }

      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);
          
      print("✅ FCM Token saved to Supabase successfully!");
    } catch (e) {
      print("❌ Error saving FCM token to Supabase: $e");
    }
  }

  // --- HANDLING MESSAGES & TAPS ---
  void _setupMessageHandlers() {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔔 FOREGROUND Message Received!");
      if (message.notification != null) {
        
        // Show an in-app Snackbar!
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.notification?.title ?? "New Notification", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                ),
                Text(message.notification?.body ?? ""),
              ],
            ),
            backgroundColor: const Color(0xFFCD9D8F), 
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            margin: const EdgeInsets.all(20),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                // Navigation logic will go here
              },
            ),
          )
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationTap(message);
      }
    });
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    if (data['type'] == 'new_match') {
      print("Navigate to Match Screen or Chat for user: ${data['matchId']}");
    } else if (data['type'] == 'new_like') {
      print("Navigate to Likes Screen to see user: ${data['likerId']}");
    }
  }
}