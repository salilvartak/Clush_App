import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User; 
import 'firebase_options.dart';
import 'basics_page.dart'; 
import 'home_page.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: 'https://roblwklgvyvjrgvyumqp.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJvYmx3a2xndnl2anJndnl1bXFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAzOTY0OTgsImV4cCI6MjA4NTk3MjQ5OH0.7kpPNmAHnGthepUIimiw_HovLOVjfX5mIWcr8WH-NrQ',
  );

  runApp(const AuraApp());
}

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VideoSplashScreen(),
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
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFFCD9D8F))),
          );
        } 
        
        if (snapshot.hasData) {
          // Check if profile exists (Basics completed)
          return FutureBuilder<bool>(
            future: _checkProfileExists(snapshot.data!.uid),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                 return const Scaffold(
                    backgroundColor: Color(0xFFE9E6E1),
                    body: Center(child: CircularProgressIndicator(color: Color(0xFFCD9D8F))),
                 );
              }

              final bool profileExists = profileSnapshot.data ?? false;

              if (profileExists) {
                // ALLOW ACCESS TO HOME PAGE (Verification check happens inside HomePage)
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

// --- VIDEO SPLASH SCREEN ---
class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({super.key});

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/Video/Video.mp4')
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });

    _controller.addListener(() {
      if (_controller.value.position == _controller.value.duration) {
        _finishSplash();
      }
    });
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
      backgroundColor: Colors.black,
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

// --- LOGIN SCREEN ---
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<User?> _signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await FirebaseAuth.instance.signInWithCredential(credential).then((cred) => cred.user);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign in failed: $e')));
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E6E1),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Image.asset("assets/images/logo.png", height: 120, fit: BoxFit.contain),
              const SizedBox(height: 50),
              const Text("Welcome back", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              const Spacer(), 
              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _signInWithGoogle(context);
                  },
                  icon: Image.network("https://cdn-icons-png.flaticon.com/512/2991/2991148.png", height: 22),
                  label: const Text("Continue with Google", style: TextStyle(fontSize: 18, color: Colors.black87)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                  ),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}