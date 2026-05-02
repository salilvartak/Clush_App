import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:clush/firebase_options.dart';
import 'package:clush/screens/basics_page.dart'; 
import 'package:clush/screens/home_page.dart';
import 'package:clush/theme/colors.dart';

import 'package:google_fonts/google_fonts.dart'; // <-- Added for typography
import 'package:flutter_animate/flutter_animate.dart'; // <-- Added for animations

// Import the notification service
import 'package:clush/services/notification_service.dart';
import 'package:clush/services/language_service.dart';
import 'package:clush/services/presence_service.dart';
import 'package:clush/services/stream_service.dart';
import 'package:clush/services/purchase_service.dart';
import 'package:clush/widgets/heart_loader.dart'; 
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:clush/l10n/app_localizations.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Initialize Supabase FIRST
  await Supabase.initialize(
    url: 'https://roblwklgvyvjrgvyumqp.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJvYmx3a2xndnl2anJndnl1bXFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAzOTY0OTgsImV4cCI6MjA4NTk3MjQ5OH0.7kpPNmAHnGthepUIimiw_HovLOVjfX5mIWcr8WH-NrQ',
  );

  // 3. Establish Supabase auth session (anonymous) so authenticated-role
  //    RLS policies work before any widget runs.
  try {
    if (Supabase.instance.client.auth.currentSession == null) {
      await Supabase.instance.client.auth.signInAnonymously();
    }
  } catch (_) {}

  // 4. Initialize Stream Chat client
  await StreamService.instance.init();

  // 5. Initialize Language Service
  final languageService = LanguageService();
  await languageService.init();

  // 6. Initialize In-App Purchase Service
  await PurchaseService.instance.init();

  runApp(const AuraApp());
}

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LanguageService().localeNotifier,
      builder: (context, locale, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('hi'),
            Locale('mr'),
          ],
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: GoogleFonts.figtree().fontFamily,
            textTheme: GoogleFonts.figtreeTextTheme(
              Theme.of(context).textTheme,
            ),
            scaffoldBackgroundColor: kCream, 
            colorScheme: ColorScheme.fromSeed(
              seedColor: kRose,
              primary: kRose,
              secondary: kGold,
              surface: kTan,
              onSurface: kBlack,
            ),
          ),
          home: const AuthWrapper(),
        );
      },
    );
  }
}

// --- AUTH WRAPPER (Allow Access to HomePage) ---
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // Cache the profile-check future so that auth token refreshes (which cause
  // StreamBuilder to rebuild) do NOT restart FutureBuilder and reset HomePageState.
  String? _cachedUid;
  Future<bool>? _profileCheckFuture;

  @override
  void initState() {
    super.initState();
    NotificationService().initNotifications();
    PresenceService.instance.start();
  }

  @override
  void dispose() {
    PresenceService.instance.stop();
    StreamService.instance.disconnect().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: kCream,
            body: Stack(
              fit: StackFit.expand,
              children: [
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(color: Colors.white.withValues(alpha: 0.18)),
                ),
                const Center(child: HeartLoader()),
              ],
            ),
          );
        }

        if (snapshot.hasData) {
          final uid = snapshot.data!.uid;
          // Only create a new Future when the signed-in user actually changes
          if (uid != _cachedUid) {
            _cachedUid = uid;
            _profileCheckFuture = _checkProfileExists(uid);
          }
          return FutureBuilder<bool>(
            future: _profileCheckFuture,
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  backgroundColor: kCream,
                  body: Stack(
                    fit: StackFit.expand,
                    children: [
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Container(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      const Center(child: HeartLoader()),
                    ],
                  ),
                );
              }

              final bool profileExists = profileSnapshot.data ?? false;

              if (profileExists) {
                return const HomePage(); 
              } else {
                return const BasicsPage(currentStep: 1, totalSteps: 6);
              }
            },
          );
        } else {
          // User signed out — reset cache so next sign-in starts fresh
          _cachedUid = null;
          _profileCheckFuture = null;
          return const LoginScreen();
        }
      },
    );
  }

  Future<bool> _checkProfileExists(String userId) async {
    final sw = Stopwatch()..start();
    try {
      final data = await Supabase.instance.client
          .from('profile_discovery')
          .select('id')
          .eq('id', userId)
          .maybeSingle(); 
      final elapsed = sw.elapsedMilliseconds;
      if (elapsed < 2200) await Future.delayed(Duration(milliseconds: 2200 - elapsed));
      return data != null;
    } catch (e) {
      final elapsed = sw.elapsedMilliseconds;
      if (elapsed < 2200) await Future.delayed(Duration(milliseconds: 2200 - elapsed));
      return false; 
    }
  }
}

// --- LOGIN SCREEN ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  String? _verificationId;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<User?> _signInWithGoogle(BuildContext context) async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return null;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await FirebaseAuth.instance
          .signInWithCredential(credential)
          .then((cred) => cred.user);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign in failed: $e')));
      }
      setState(() => _isLoading = false);
      return null;
    }
  }

  Future<void> _verifyPhoneNumber() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a phone number')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone.startsWith('+') ? phone : '+91$phone', 
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification failed: ${e.message}')));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
            });
          }
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _signInWithOTP() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || _verificationId == null) return;

    setState(() => _isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid OTP. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCream,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 50),
                        
                        Hero(
                          tag: 'app_logo',
                          child: Image.asset("assets/images/logo.png", height: 100, fit: BoxFit.contain),
                        ),
                        const SizedBox(height: 40),
                        
                        const Spacer(), 
                        
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeOutQuart,
                          switchOutCurve: Curves.easeInQuart,
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.05),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: _verificationId == null 
                              ? _buildPhoneInputState() 
                              : _buildOTPInputState(),
                        ),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- PHONE INPUT WIDGET ---
  Widget _buildPhoneInputState() {
    return Column(
      key: const ValueKey('phone_state'),
      children: [
        Container(
          decoration: BoxDecoration(color: kParchment,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: kInk.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: "Phone Number (e.g., +91...)",
              hintStyle: const TextStyle(color: kInkMuted, fontSize: 16),
              prefixIcon: const Icon(Icons.phone_outlined, color: kRose),
              filled: true,
              fillColor: Colors.transparent, // Let the container drive the color
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyPhoneNumber,
            style: ElevatedButton.styleFrom(
              backgroundColor: kRose,
              elevation: 8,
              shadowColor: kRose.withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: _isLoading 
                ? const HeartLoader(size: 26, color: Colors.white) 
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Continue", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      SizedBox(width: 12),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                    ],
                  ),
          ),
        ).animate().fade(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
        
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Row(
            children: [
              Expanded(child: Divider(color: kBone)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text("OR", style: TextStyle(color: kInkMuted, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Expanded(child: Divider(color: kBone)),
            ],
          ),
        ),
        
        SizedBox(
          width: double.infinity,
          height: 60,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : () => _signInWithGoogle(context),
            icon: Image.network("https://cdn-icons-png.flaticon.com/512/2991/2991148.png", height: 26),
            label: const Text("Continue with Google", style: TextStyle(fontSize: 16, color: kInk, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
            style: OutlinedButton.styleFrom(
              backgroundColor: kCream,
              elevation: 4,
              shadowColor: kInk.withOpacity(0.05),
              side: const BorderSide(color: Colors.transparent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ).animate().fade(duration: 400.ms, delay: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
      ],
    );
  }

  // --- OTP INPUT WIDGET ---
  Widget _buildOTPInputState() {
    return Column(
      key: const ValueKey('otp_state'),
      children: [
        Container(
          decoration: BoxDecoration(color: kParchment,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: kInk.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(fontSize: 28, letterSpacing: 14.0, fontWeight: FontWeight.bold, color: kBlack),
            decoration: InputDecoration(
              counterText: "",
              hintText: "------",
              hintStyle: const TextStyle(letterSpacing: 14.0, color: kBone),
              filled: true,
              fillColor: Colors.transparent,
              prefixIcon: const Icon(Icons.lock_outline, color: kRose),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _signInWithOTP,
            style: ElevatedButton.styleFrom(
              backgroundColor: kRose,
              elevation: 8,
              shadowColor: kRose.withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: _isLoading 
                ? const HeartLoader(size: 26, color: Colors.white)
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Text("Verify Code", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ],
                  ),
          ),
        ).animate().fade(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _verificationId = null;
              _otpController.clear();
            });
          },
          style: TextButton.styleFrom(
            foregroundColor: kInkMuted,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text("Use a different number", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ).animate().fade(duration: 400.ms, delay: 300.ms),
      ],
    );
  }
}
