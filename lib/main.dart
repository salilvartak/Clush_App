import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_drawing/path_drawing.dart'; // <-- Added for SVG Path drawing
import 'package:supabase_flutter/supabase_flutter.dart' hide User; 
import 'firebase_options.dart';
import 'basics_page.dart'; 
import 'home_page.dart';
import 'dart:ui';

// Import the notification service
import 'services/notification_service.dart'; 

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

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

  // Note: We DO NOT initialize notifications here anymore so we don't block the UI!
  
  runApp(const AuraApp());
}

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AnimatedSplashScreen(), // <-- Changed from LottieSplashScreen
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
  
  @override
  void initState() {
    super.initState();
    // 3. Initialize notifications AFTER the UI starts drawing
    // This will prompt the user for permission without freezing the app
    NotificationService().initNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: HeartLoader()), // <-- Replaced with HeartLoader
          );
        } 
        
        if (snapshot.hasData) {
          return FutureBuilder<bool>(
            future: _checkProfileExists(snapshot.data!.uid),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                 return const Scaffold(
                    backgroundColor: Color(0xFFE9E6E1),
                    body: Center(child: HeartLoader()), // <-- Replaced with HeartLoader
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
          return const LoginScreen(); 
        }
      },
    );
  }

  Future<bool> _checkProfileExists(String userId) async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle(); 
      return data != null;
    } catch (e) {
      return false; 
    }
  }
}

// --- NEW ANIMATED SPLASH SCREEN (SVG PATH DRAWING) ---
class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Set duration to 3.5 seconds to match the CSS version we made
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finishSplash();
      }
    });

    // Start drawing immediately
    _controller.forward();
  }

  void _finishSplash() {
    Navigator.of(context).pushReplacement(_createFadeRoute(const AuthWrapper()));
  }

  Route _createFadeRoute(Widget destination) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => destination,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E6E1), 
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Using a container to limit the drawing width nicely on screen
            return SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              height: 200, 
              child: CustomPaint(
                painter: LogoPainter(_controller.value),
              ),
            );
          },
        ),
      ),
    );
  }
}

// --- LOGO PAINTER ---
class LogoPainter extends CustomPainter {
  final double progress;

  LogoPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // Theme matching the rest of the app!
    final strokePaint = Paint()
      ..color = const Color(0xFFCD9D8F) 
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = const Color(0xFFCD9D8F).withOpacity(progress == 1.0 ? 1.0 : 0.0)
      ..style = PaintingStyle.fill;

    // Scale so the massive 1400px SVG fits properly inside the widget Size
    final double scale = size.width / 1400;
    canvas.scale(scale, scale);
    
    // Centers the drawing vertically based on original coordinates
    canvas.translate(20, 480); 

    // The 'Clash' paths
    final Map<Offset, String> letters = {
      // C
      const Offset(0, 0): "M 19.89 -198.87 C 19.89 -229.89 25.05 -258.06 35.39 -283.39 C 45.73 -308.71 59.98 -330.51 78.15 -348.81 C 96.32 -367.11 117.39 -381.17 141.39 -390.98 C 165.39 -400.79 191.04 -405.70 218.35 -405.70 C 236.39 -405.70 254.28 -404.04 272.04 -400.73 C 289.81 -397.42 305.92 -392.51 320.37 -386.01 C 334.83 -379.51 346.43 -371.42 355.18 -361.75 C 363.93 -352.07 368.31 -340.86 368.31 -328.14 C 368.31 -320.71 366.78 -315.47 363.73 -312.42 C 360.69 -309.37 357.71 -307.59 354.79 -307.06 C 351.87 -306.53 350.42 -306.26 350.42 -306.26 C 348.82 -317.39 344.31 -328.40 336.89 -339.28 C 329.46 -350.15 319.71 -359.96 307.65 -368.71 C 295.59 -377.46 281.93 -384.49 266.68 -389.79 C 251.44 -395.09 235.33 -397.75 218.35 -397.75 C 195.29 -397.75 173.75 -393.03 153.73 -383.62 C 133.71 -374.21 116.00 -360.69 100.62 -343.06 C 85.25 -325.42 73.25 -304.47 64.62 -280.21 C 56.00 -255.95 51.70 -228.84 51.70 -198.87 C 51.70 -169.17 56.00 -142.12 64.62 -117.73 C 73.25 -93.33 85.25 -72.32 100.62 -54.68 C 116.00 -37.05 133.71 -23.52 153.73 -14.10 C 173.75 -4.70 195.29 0 218.35 0 C 239.30 0 259.45 -4.23 278.81 -12.71 C 298.17 -21.20 315.87 -32.08 331.92 -45.34 C 347.96 -58.60 361.01 -72.52 371.09 -87.10 L 371.09 -42.56 C 364.72 -32.75 353.78 -24.06 338.28 -16.5 C 322.76 -8.94 304.60 -2.98 283.79 1.39 C 262.98 5.76 241.17 7.95 218.35 7.95 C 191.04 7.95 165.39 3.04 141.39 -6.76 C 117.39 -16.57 96.32 -30.62 78.15 -48.92 C 59.98 -67.22 45.73 -89.03 35.39 -114.35 C 25.05 -139.67 19.89 -167.85 19.89 -198.87 Z",
      // l
      const Offset(396.74, 0): "M 59.65 0 L 27.84 0 L 27.84 -397.75 L 59.65 -397.75 Z",
      // a
      const Offset(484.24, 0): "M 17.90 -251.78 C 17.90 -258.40 20.48 -263.37 25.65 -266.68 C 30.82 -270 37.11 -272.25 44.54 -273.45 C 51.97 -274.64 58.86 -275.25 65.23 -275.25 L 109.78 -275.25 C 112.69 -275.25 114.68 -274.51 115.75 -273.06 C 116.81 -271.60 117.34 -269.94 117.34 -268.07 C 117.34 -264.36 115.08 -259.66 110.57 -253.95 C 106.06 -248.25 100.49 -241.42 93.85 -233.46 C 87.23 -225.51 80.60 -216.24 73.96 -205.64 C 67.34 -195.03 61.77 -182.96 57.26 -169.43 C 52.76 -155.91 50.51 -140.53 50.51 -123.29 C 50.51 -107.39 52.83 -92.27 57.46 -77.95 C 62.11 -63.64 68.67 -50.91 77.15 -39.76 C 85.64 -28.62 95.78 -19.87 107.59 -13.51 C 119.39 -7.16 132.45 -3.98 146.76 -3.98 C 160.55 -3.98 173.14 -6.89 184.54 -12.73 C 195.95 -18.56 205.76 -26.25 213.98 -35.79 C 222.20 -45.33 228.56 -55.74 233.07 -67.01 C 237.58 -78.28 239.84 -89.22 239.84 -99.82 L 239.84 -275.25 L 271.65 -275.25 L 271.65 0 L 239.84 0 L 239.84 -29.82 C 239.84 -36.99 238.25 -40.57 235.06 -40.57 C 232.94 -40.57 230.03 -38.71 226.31 -35 C 214.64 -23.07 201.32 -12.92 186.34 -4.57 C 171.36 3.77 152.47 7.95 129.67 7.95 C 112.42 7.95 97.05 4.76 83.53 -1.59 C 70.00 -7.95 58.60 -16.57 49.32 -27.43 C 40.04 -38.31 32.95 -50.70 28.04 -64.62 C 23.14 -78.55 20.68 -93.07 20.68 -108.18 C 20.68 -125.42 23.46 -141.33 29.03 -155.92 C 34.60 -170.50 41.56 -183.62 49.92 -195.29 C 58.27 -206.96 66.56 -217.30 74.78 -226.31 C 83 -235.33 89.89 -242.95 95.45 -249.18 C 101.02 -255.41 103.81 -260.25 103.81 -263.70 C 103.81 -265.82 102.67 -266.95 100.42 -267.07 C 98.17 -267.21 96.25 -267.28 94.67 -267.28 L 67.62 -267.28 C 59.39 -267.28 53.22 -265.89 49.10 -263.10 C 45.00 -260.32 42.08 -257.14 40.35 -253.56 C 38.64 -249.98 36.98 -246.80 35.39 -244.01 C 33.80 -241.23 31.15 -239.84 27.43 -239.84 C 25.58 -239.84 23.53 -240.83 21.28 -242.82 C 19.03 -244.81 17.90 -247.80 17.90 -251.78 Z",
      // s
      const Offset(785.31, 0): "M 21.48 -49.71 C 21.48 -54.22 23.00 -58.00 26.04 -61.04 C 29.09 -64.09 32.87 -65.62 37.39 -65.62 C 42.16 -65.62 46.39 -63.43 50.10 -59.06 C 53.82 -54.68 57.73 -49.25 61.84 -42.75 C 65.95 -36.25 70.92 -29.69 76.76 -23.06 C 82.59 -16.43 90.01 -10.93 99.03 -6.56 C 108.05 -2.18 119.45 0 133.25 0 C 145.97 0 157.91 -2.05 169.04 -6.15 C 180.17 -10.26 189.85 -15.70 198.07 -22.46 C 206.29 -29.22 212.72 -36.51 217.35 -44.34 C 222.00 -52.16 224.32 -59.78 224.32 -67.21 C 224.32 -79.41 221.53 -89.35 215.96 -97.04 C 210.40 -104.73 202.84 -110.76 193.29 -115.14 C 183.75 -119.52 173.08 -123.10 161.28 -125.89 C 149.48 -128.67 137.35 -131.18 124.89 -133.43 C 112.42 -135.69 100.30 -138.48 88.50 -141.79 C 76.69 -145.10 66.01 -149.48 56.46 -154.92 C 46.92 -160.35 39.36 -167.64 33.79 -176.79 C 28.23 -185.94 25.45 -197.67 25.45 -212 C 25.45 -225.25 29.42 -237.25 37.39 -248 C 45.34 -258.73 56.94 -267.28 72.18 -273.65 C 87.43 -280.01 106.19 -283.20 128.46 -283.20 C 161.88 -283.20 187.00 -280.08 203.84 -273.84 C 220.68 -267.61 229.10 -259.06 229.10 -248.20 C 229.10 -245.28 227.58 -242.42 224.53 -239.64 C 221.47 -236.85 217.96 -235.46 213.98 -235.46 C 207.89 -235.46 202.05 -237.58 196.48 -241.82 C 190.92 -246.07 184.95 -251.05 178.59 -256.75 C 172.22 -262.44 165.06 -267.41 157.10 -271.65 C 149.14 -275.90 139.73 -278.03 128.87 -278.03 C 114.28 -278.03 101.62 -275.11 90.89 -269.28 C 80.14 -263.44 71.79 -256.01 65.82 -247 C 59.85 -237.98 56.87 -228.57 56.87 -218.76 C 56.87 -206.82 60.32 -197.47 67.21 -190.71 C 74.11 -183.95 83.19 -178.71 94.46 -175 C 105.73 -171.28 118.13 -168.17 131.65 -165.65 C 145.17 -163.14 158.69 -160.29 172.21 -157.10 C 185.75 -153.92 198.14 -149.48 209.40 -143.78 C 220.67 -138.08 229.75 -130.19 236.65 -120.10 C 243.55 -110.03 247 -96.78 247 -80.34 C 247 -61.51 241.75 -45.47 231.28 -32.21 C 220.81 -18.95 206.69 -8.94 188.92 -2.18 C 171.16 4.57 151.14 7.95 128.87 7.95 C 114.82 7.95 101.36 6.22 88.50 2.78 C 75.63 -0.66 64.16 -5.23 54.09 -10.93 C 44.01 -16.63 36.06 -22.86 30.23 -29.62 C 24.39 -36.39 21.48 -43.09 21.48 -49.71 Z",
      // h
      const Offset(1050.99, 0): "M 27.84 0 L 27.84 -397.75 L 59.65 -397.75 L 59.65 -245.81 C 59.65 -239.17 60.85 -235.85 63.25 -235.85 C 64.83 -235.85 67.75 -237.71 72 -241.43 C 86.31 -255.21 101.55 -265.62 117.73 -272.65 C 133.91 -279.68 152.33 -283.20 173.01 -283.20 C 193.17 -283.20 210.86 -279.28 226.10 -271.46 C 241.35 -263.64 253.28 -252.83 261.90 -239.04 C 270.53 -225.25 274.84 -209.34 274.84 -191.31 L 274.84 0 L 243.03 0 L 243.03 -190.51 C 243.03 -209.34 239.44 -224.99 232.28 -237.45 C 225.12 -249.92 215.71 -259.33 204.04 -265.70 C 192.37 -272.06 179.91 -275.25 166.65 -275.25 C 153.39 -275.25 140.39 -272.72 127.67 -267.68 C 114.94 -262.64 103.47 -255.81 93.26 -247.20 C 83.05 -238.58 74.89 -228.84 68.79 -217.96 C 62.70 -207.09 59.65 -195.82 59.65 -184.15 L 59.65 0 Z",
    };

    letters.forEach((offset, pathString) {
      Path path = parseSvgPathData(pathString).shift(offset);

      for (PathMetric metric in path.computeMetrics()) {
        Path extractedPath = metric.extractPath(0.0, metric.length * progress);
        canvas.drawPath(extractedPath, strokePaint);
      }

      // Smoothly fill in at the end 
      if (progress > 0.7) {
        canvas.drawPath(path, fillPaint);
      }
    });
  }

  @override
  bool shouldRepaint(LogoPainter oldDelegate) {
    return oldDelegate.progress != progress;
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
      backgroundColor: const Color(0xFFE9E6E1),
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
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: "Phone Number (e.g., +91...)",
            hintStyle: const TextStyle(color: Colors.black38),
            prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFFCD9D8F)),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: const BorderSide(color: Colors.white, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: const BorderSide(color: Color(0xFFCD9D8F), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyPhoneNumber,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCD9D8F),
              elevation: 2,
              shadowColor: const Color(0xFFCD9D8F).withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
            ),
            child: _isLoading 
                ? const HeartLoader(size: 26, color: Colors.white) // <-- Replaced with HeartLoader
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Send OTP", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    ],
                  ),
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 28.0),
          child: Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade400)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text("OR", style: TextStyle(color: Colors.black45, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Expanded(child: Divider(color: Colors.grey.shade400)),
            ],
          ),
        ),
        
        SizedBox(
          width: double.infinity,
          height: 58,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : () => _signInWithGoogle(context),
            icon: Image.network("https://cdn-icons-png.flaticon.com/512/2991/2991148.png", height: 24),
            label: const Text("Continue with Google", style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              elevation: 1,
              shadowColor: Colors.black12,
              side: const BorderSide(color: Colors.transparent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
            ),
          ),
        ),
      ],
    );
  }

  // --- OTP INPUT WIDGET ---
  Widget _buildOTPInputState() {
    return Column(
      key: const ValueKey('otp_state'),
      children: [
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(fontSize: 24, letterSpacing: 12.0, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D)),
          decoration: InputDecoration(
            counterText: "",
            hintText: "------",
            hintStyle: const TextStyle(letterSpacing: 12.0, color: Colors.black26),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFCD9D8F)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: const BorderSide(color: Colors.white, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: const BorderSide(color: Color(0xFFCD9D8F), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _signInWithOTP,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCD9D8F),
              elevation: 2,
              shadowColor: const Color(0xFFCD9D8F).withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
            ),
            child: _isLoading 
                ? const HeartLoader(size: 26, color: Colors.white) // <-- Replaced with HeartLoader
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Text("Verify Code", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _verificationId = null;
              _otpController.clear();
            });
          },
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFCD9D8F),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text("Use a different number", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        )
      ],
    );
  }
}

// --- NEW HEART LOADER WIDGET ---
class HeartLoader extends StatefulWidget {
  final double size;
  final Color color;

  const HeartLoader({
    super.key,
    this.size = 50.0, // Default size for full screens
    this.color = const Color(0xFFCD9D8F), // Your brand peach color
  });

  @override
  State<HeartLoader> createState() => _HeartLoaderState();
}

class _HeartLoaderState extends State<HeartLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // 600ms gives a nice, natural heartbeat rhythm
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true); // Reverses automatically to "beat" back down
    
    // Scales the heart from 85% to 115% size
    _animation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: child,
        );
      },
      // Passing child here is an optimization so Flutter doesn't rebuild the Icon
      child: Icon(
        Icons.favorite, // You can change this to Icons.favorite_border for an outlined heart
        color: widget.color,
        size: widget.size,
      ),
    );
  }
}