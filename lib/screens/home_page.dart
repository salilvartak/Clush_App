import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clush/providers/matches_provider.dart';
import 'package:clush/screens/discover_page.dart';
import 'package:clush/screens/likes_page.dart';
import 'package:clush/screens/matches_page.dart';
import 'package:clush/screens/profile_tab.dart';
import 'package:clush/theme/colors.dart';

final GlobalKey<HomePageState> homeKey = GlobalKey<HomePageState>();

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends ConsumerState<HomePage> {
  static int _selectedIndex = 0;
  late final PageController _pageController;

  // Tab pages are created once and kept alive by AutomaticKeepAliveClientMixin.
  static const List<Widget> _pages = [
    DiscoverPage(),
    LikesPage(),
    MatchesPage(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void setIndex(int index) {
    if (!mounted) return;
    setState(() => _selectedIndex = index);
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadCountProvider).value ?? 0;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (i) => setState(() => _selectedIndex = i),
        children: _pages,
      ),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        unreadCount: unreadCount,
        onTap: (i) {
          if (i != _selectedIndex) {
            _pageController.animateToPage(
              i,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeInOutQuart,
            );
          }
        },
      ),
    );
  }
}

// â”€â”€â”€ Bottom navigation bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selectedIndex,
    required this.unreadCount,
    required this.onTap,
  });

  final int selectedIndex;
  final int unreadCount;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kCream,
        border: Border(top: BorderSide(color: kBone)),
      ),
      child: BottomNavigationBar(
        key: const ValueKey('bottom_nav'),
        currentIndex: selectedIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: kCream,
        elevation: 0,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: kRose,
        unselectedItemColor: kInkMuted,
        iconSize: 26,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.style_outlined),
            activeIcon: Icon(Icons.style_rounded),
            label: '',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              backgroundColor: kRose,
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
            activeIcon: Badge(
              isLabelVisible: unreadCount > 0,
              backgroundColor: kRose,
              child: const Icon(Icons.chat_bubble_rounded),
            ),
            label: '',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: '',
          ),
        ],
      ),
    );
  }
}

