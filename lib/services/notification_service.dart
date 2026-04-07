import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clush/main.dart'; 
import 'package:clush/services/stream_service.dart';
import 'package:clush/widgets/notification_overlay.dart';
import 'package:stream_chat_flutter_core/stream_chat_flutter_core.dart';

// TOP-LEVEL FUNCTION FOR BACKGROUND MESSAGES
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Logic for background messages if needed
  print("🔔 Background push received: ${message.notification?.title}");
}

/**
 * 🚀 CLUSH UNIFIED NOTIFICATION SERVICE
 * Rebuilt for simplicity and performance.
 * Handles Likes, Matches, Messages, and Promos via a unified 'push-engine'.
 */
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();
  factory NotificationService() => instance;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initNotifications({BuildContext? context, bool force = false}) async {
    // 1. Check user preference
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('notifications_enabled') ?? true;
    if (!isEnabled) return;

    // 2. Request Permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 3. Register Token
      await updateToken();

      // 4. Setup Handlers
      _setupHandlers();
    }
  }

  Future<void> updateToken() async {
    final token = await _fcm.getToken();
    if (token == null) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      // Save to Supabase (for system-wide push engine)
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);

      // Register with Stream Chat (for real-time message push)
      final streamClient = StreamService.instance.client;
      if (streamClient.state.currentUser != null) {
        await streamClient.addDevice(token, PushProvider.firebase);
      }
      
      print("✅ FCM Token synchronized across all services.");
    } catch (e) {
      print("⚠️ Error syncing FCM token: $e");
    }
  }

  void _setupHandlers() {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Foreground Listeners
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
       _showInAppNotification(message);
    });

    // Interaction Listeners
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    _fcm.getInitialMessage().then((msg) { if (msg != null) _handleTap(msg); });
  }

  void _showInAppNotification(RemoteMessage message) {
    if (message.notification == null) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    NotificationOverlay.show(
      context,
      title: message.notification!.title ?? "New Notification",
      body: message.notification!.body ?? "",
      type: message.data['type'] as String?,
      onTap: () => _handleTap(message),
    );
  }

  void _handleTap(RemoteMessage message) {
    final type = message.data['type'];
    final payload = message.data;

    print("👆 Notification tapped: $type");

    switch (type) {
      case 'new_match':
        // Navigate to match/chat
        break;
      case 'new_like':
        // Navigate to likes
        break;
      case 'promo':
        // Navigate to specific URL or page
        break;
      default:
        // Default behavior (open app)
    }
  }

  Future<void> clearAll() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await _fcm.deleteToken();
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': null})
          .eq('id', userId);
    }
  }

  Future<void> toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (value) {
      await initNotifications(force: true);
    } else {
      await clearAll();
    }
  }
}
