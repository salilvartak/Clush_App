import 'dart:ui' show ImageFilter;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:video_player/video_player.dart';

import 'package:clush/firebase_options.dart';
import 'package:clush/l10n/app_localizations.dart';
import 'package:clush/screens/basics_page.dart';
import 'package:clush/screens/home_page.dart';
import 'package:clush/screens/get_verified_screen.dart';
import 'package:clush/screens/pending_screen.dart';
import 'package:clush/screens/rejected_screen.dart';
import 'package:clush/services/cache_service.dart';
import 'package:clush/services/language_service.dart';
import 'package:clush/services/notification_service.dart';
import 'package:clush/services/presence_service.dart';
import 'package:clush/services/purchase_service.dart';
import 'package:clush/services/stream_service.dart';
import 'package:clush/theme/colors.dart';
import 'package:clush/widgets/heart_loader.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Initialize Supabase FIRST
  await Supabase.initialize(
    url: 'https://roblwklgvyvjrgvyumqp.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJvYmx3a2xndnl2anJndnl1bXFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAzOTY0OTgsImV4cCI6MjA4NTk3MjQ5OH0.7kpPNmAHnGthepUIimiw_HovLOVjfX5mIWcr8WH-NrQ',
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

  runApp(const ProviderScope(child: AuraApp()));
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
          supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
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
              onPrimary: Colors.white,
              secondary: kGold,
              onSecondary: kBlack,
              surface: kTan,
              onSurface: kBlack,
              error: kDestructive,
            ),
            cardColor: kCard,
            dividerColor: kBone,
            appBarTheme: const AppBarTheme(
              backgroundColor: kCream,
              foregroundColor: kBlack,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: kRose,
                foregroundColor: Colors.white,
              ),
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
  Future<String>? _profileCheckFuture;

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
            _profileCheckFuture = _checkProfileStatus(uid);
          }
          return FutureBuilder<String>(
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
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      const Center(child: HeartLoader()),
                    ],
                  ),
                );
              }

              final String status = profileSnapshot.data ?? 'not_found';

              if (status == 'verified' || status == 'approved') {
                CacheService.instance.prefetchAndCache();
                return HomePage(key: homeKey);
              } else if (status == 'pending') {
                return const PendingScreen();
              } else if (status == 'rejected') {
                return const RejectedScreen();
              } else if (status == 'not_verified') {
                return const GetVerifiedScreen();
              } else {
                // 'not_found' — no profile yet, go through onboarding
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

  Future<String> _checkProfileStatus(String userId) async {
    final sw = Stopwatch()..start();
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('verification_status')
          .eq('id', userId)
          .maybeSingle();
      final elapsed = sw.elapsedMilliseconds;
      if (elapsed < 2200) {
        await Future.delayed(Duration(milliseconds: 2200 - elapsed));
      }
      if (data == null) return 'not_found';
      return data['verification_status'] as String? ?? 'not_verified';
    } catch (e) {
      final elapsed = sw.elapsedMilliseconds;
      if (elapsed < 2200) {
        await Future.delayed(Duration(milliseconds: 2200 - elapsed));
      }
      return 'not_found';
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
  late final VideoPlayerController _bgVideoController;

  String? _verificationId;
  bool _isLoading = false;

  // Country code picker state
  String _dialCode = '+91';
  String _countryFlag = '🇮🇳';

  static const List<(String, String, String)> _countries = [
    ('🇮🇳', '+91',  'India'),
    ('🇺🇸', '+1',   'United States'),
    ('🇨🇦', '+1',   'Canada'),
    ('🇬🇧', '+44',  'United Kingdom'),
    ('🇦🇺', '+61',  'Australia'),
    ('🇦🇪', '+971', 'UAE'),
    ('🇸🇬', '+65',  'Singapore'),
    ('🇳🇿', '+64',  'New Zealand'),
    ('🇿🇦', '+27',  'South Africa'),
    ('🇩🇪', '+49',  'Germany'),
    ('🇫🇷', '+33',  'France'),
    ('🇮🇹', '+39',  'Italy'),
    ('🇳🇱', '+31',  'Netherlands'),
    ('🇸🇪', '+46',  'Sweden'),
    ('🇧🇷', '+55',  'Brazil'),
    ('🇲🇽', '+52',  'Mexico'),
    ('🇯🇵', '+81',  'Japan'),
    ('🇨🇳', '+86',  'China'),
    ('🇰🇷', '+82',  'South Korea'),
    ('🇵🇭', '+63',  'Philippines'),
    ('🇲🇾', '+60',  'Malaysia'),
    ('🇮🇩', '+62',  'Indonesia'),
    ('🇧🇩', '+880', 'Bangladesh'),
    ('🇵🇰', '+92',  'Pakistan'),
    ('🇳🇬', '+234', 'Nigeria'),
    ('🇰🇪', '+254', 'Kenya'),
    ('🇬🇭', '+233', 'Ghana'),
    ('🇸🇦', '+966', 'Saudi Arabia'),
    ('🇶🇦', '+974', 'Qatar'),
    ('🇧🇭', '+973', 'Bahrain'),
    ('🇴🇲', '+968', 'Oman'),
    ('🇮🇱', '+972', 'Israel'),
    ('🇬🇷', '+30',  'Greece'),
    ('🇵🇱', '+48',  'Poland'),
  ];

  @override
  void initState() {
    super.initState();
    _bgVideoController = VideoPlayerController.asset('assets/images/login_1.mp4')
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _bgVideoController.play();
        }
      });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _bgVideoController.dispose();
    super.dispose();
  }



  Future<void> _verifyPhoneNumber() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '$_dialCode${phone.replaceAll(RegExp(r'^\+'), '')}',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Verification failed: ${e.message}')),
            );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _signInWithOTP() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || _verificationId == null || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = result.user;
      if (user != null) {
        final fullPhone = '$_dialCode${_phoneController.text.trim().replaceAll(RegExp(r'^\+'), '')}';
        await Supabase.instance.client.from('profiles').upsert(
          {'id': user.uid, 'phone': fullPhone},
          onConflict: 'id',
          ignoreDuplicates: false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid OTP. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background video (looping, muted)
          if (_bgVideoController.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _bgVideoController.value.size.width,
                height: _bgVideoController.value.size.height,
                child: VideoPlayer(_bgVideoController),
              ),
            )
          else
            Image.asset(
              'assets/images/bg.png',
              fit: BoxFit.cover,
            ),
          // Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 50),

                            Hero(
                              tag: 'app_logo',
                              child: Image.asset(
                                "assets/images/bg_removed.png",
                                height: 200,
                                fit: BoxFit.contain,
                              ),
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
        ],
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kBone,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select country',
                  style: GoogleFonts.gabarito(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: kBlack,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _countries.length,
                    itemBuilder: (_, i) {
                      final (flag, code, name) = _countries[i];
                      final selected = code == _dialCode && flag == _countryFlag;
                      return ListTile(
                        leading: Text(flag, style: const TextStyle(fontSize: 26)),
                        title: Text(
                          name,
                          style: GoogleFonts.figtree(
                            color: kBlack,
                            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        trailing: Text(
                          code,
                          style: GoogleFonts.figtree(
                            color: selected ? kRose : kInkMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        tileColor: selected ? kRose.withValues(alpha: 0.06) : null,
                        onTap: () {
                          setState(() {
                            _dialCode = code;
                            _countryFlag = flag;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- PHONE INPUT WIDGET ---
  Widget _buildPhoneInputState() {
    return Column(
      key: const ValueKey('phone_state'),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              // Country code picker (no flag)
              GestureDetector(
                onTap: _showCountryPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dialCode,
                        style: GoogleFonts.figtree(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white70),
                    ],
                  ),
                ),
              ),
              // Number field
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.figtree(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Phone number',
                    hintStyle: GoogleFonts.figtree(
                      color: Colors.white54,
                      fontSize: 15,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isLoading
                    ? const HeartLoader(size: 26, color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Continue",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ],
                      ),
              ),
            )
            .animate()
            .fade(duration: 400.ms, delay: 200.ms)
      ],
    );
  }

  // --- OTP INPUT WIDGET ---
  Widget _buildOTPInputState() {
    return Column(
      key: const ValueKey('otp_state'),
      children: [
        AutofillGroup(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              autofillHints: const [AutofillHints.oneTimeCode],
              style: const TextStyle(
                fontSize: 26,
                letterSpacing: 14.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                counterText: "",
                hintText: "------",
                hintStyle: const TextStyle(letterSpacing: 14.0, color: Colors.white38),
                filled: true,
                fillColor: Colors.transparent,
                prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 12.0,
                ),
              ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isLoading
                    ? const HeartLoader(size: 26, color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Verify Code",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            )
            .animate()
            .fade(duration: 400.ms, delay: 200.ms)
            .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _verificationId = null;
              _otpController.clear();
            });
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.white70,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text(
            "Use a different number",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ).animate().fade(duration: 400.ms, delay: 300.ms),
      ],
    );
  }
}
