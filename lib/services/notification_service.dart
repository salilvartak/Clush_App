import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:flutter/material.dart';

// Import main.dart so we can access the global scaffoldMessengerKey
import '../main.dart'; 

// 1. TOP-LEVEL FUNCTION FOR BACKGROUND MESSAGES
// This MUST be outside of any class to run when the app is minimized/killed.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🔔 Background message received: ${message.notification?.title}");
  // You can put logic here if you need to update a local database, 
  // but usually, you just let the system display the standard notification.
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initNotifications() async {
    // 1. Request permissions (shows the OS popup)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
      
      // 2. Get the token
      String? token = await _fcm.getToken();
      print('FCM Device Token: $token');

      // 3. Save the token to Supabase
      if (token != null) {
        await _saveTokenToDatabase(token);
      }

      // 4. Listen for token refreshes in the background
      _fcm.onTokenRefresh.listen((newToken) {
        _saveTokenToDatabase(newToken);
      });

      // 5. Initialize listeners for incoming messages and taps
      _setupMessageHandlers();
      
    } else {
      print('User declined or has not accepted permission');
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
    // 1. Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Handle messages while the app is actively OPEN (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔔 FOREGROUND Message Received!");
      if (message.notification != null) {
        print('Message Title: ${message.notification?.title}');
        print('Message Body: ${message.notification?.body}');
        
        // Show an in-app Snackbar so the user knows they got a notification!
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
            backgroundColor: const Color(0xFFCD9D8F), // Your kRose premium color
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            margin: const EdgeInsets.all(20),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                // We will handle navigation here later
              },
            ),
          )
        );
      }
    });

    // 3. Handle when a user TAPS the notification while app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("👆 User TAPPED a notification from the background!");
      _handleNotificationTap(message);
    });

    // 4. Handle when a user TAPS the notification to open a fully closed/terminated app
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print("🚀 App opened from a terminated state via notification tap!");
        _handleNotificationTap(message);
      }
    });
  }

  // --- NAVIGATION ROUTING ---
  void _handleNotificationTap(RemoteMessage message) {
    // Check the hidden 'data' payload of the notification
    // e.g., if we send { "type": "new_match", "matchId": "123" } from the backend
    final data = message.data;
    
    if (data['type'] == 'new_match') {
      print("Navigate to Match Screen or Chat for user: ${data['matchId']}");
      // TODO: Add Navigation logic here later using a global navigator key
    }
  }
}