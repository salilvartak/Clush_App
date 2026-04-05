import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clush/theme/colors.dart';

enum PermissionType { camera, location, notifications, contacts }

class PermissionRequestPage extends StatelessWidget {
  final PermissionType type;
  final VoidCallback onAllow;
  final VoidCallback onDecline;

  const PermissionRequestPage({
    super.key,
    required this.type,
    required this.onAllow,
    required this.onDecline,
  });

  /// Helper to show this page and return a result
  static Future<bool?> show(BuildContext context, PermissionType type) {
    return Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PermissionRequestPage(
          type: type,
          onAllow: () => Navigator.pop(context, true),
          onDecline: () => Navigator.pop(context, false),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = "";
    String description = "";
    IconData icon = Icons.lock_outline;
    String allowLabel = "Allow";
    String declineLabel = "Maybe Later";

    switch (type) {
      case PermissionType.camera:
        title = "Access Your Camera";
        description = "To verify your identity and show you're real, we need access to your camera for a 5-second video.";
        icon = Icons.camera_alt_outlined;
        break;
      case PermissionType.location:
        title = "Find People Nearby";
        description = "We use your location to show you amazing people in your city. Your exact coordinates are never shared.";
        icon = Icons.location_on_outlined;
        break;
      case PermissionType.notifications:
        title = "Stay Connected";
        description = "Get notified instantly when someone likes you back or sends you a message. Don't miss a beat.";
        icon = Icons.notifications_none_outlined;
        break;
      case PermissionType.contacts:
        title = "Sync Contacts";
        description = "Find friends already on Clush or ensure you don't run into people you already know.";
        icon = Icons.contacts_outlined;
        break;
    }

    return Scaffold(
      backgroundColor: kTan,
      body: Stack(
        children: [
          // Background Gradient/Details
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: kRosePale.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  
                  // Premium Icon Container
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: kParchment,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kInk.withOpacity(0.08),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        size: 48,
                        color: kRose,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Text Content
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.gabarito(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: kBlack,
                      letterSpacing: -0.5,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.figtree(
                      fontSize: 16,
                      color: kInkMuted,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Buttons
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton(
                          onPressed: onAllow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kRose,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: kRose.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            allowLabel,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      TextButton(
                        onPressed: onDecline,
                        style: TextButton.styleFrom(
                          foregroundColor: kInkMuted,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                        ),
                        child: Text(
                          declineLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
