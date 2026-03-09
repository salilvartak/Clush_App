import sys
import re

file_path = r'c:\Users\Salil\Desktop\Flutter\Clush_App\lib\discover_page.dart'
try:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
except FileNotFoundError:
    print("File not found")
    sys.exit(1)

# Make sure backgroundColor is kBgColor everywhere
content = content.replace("backgroundColor: kTan", "backgroundColor: kBgColor")

#### REPLACEMENT 1: Empty state ####
empty_state_old = """    if (_profiles.isEmpty) {
      return Scaffold(
        backgroundColor: kBgColor,
        body: Stack(
          children: [
            const Center(child: Text("No more profiles found!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildHeader(context),
            ),
          ],
        ),
      );
    }"""
    
empty_state_new = """    if (_profiles.isEmpty) {
      return Scaffold(
        backgroundColor: kBgColor,
        body: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.style_rounded, size: 64, color: kRose.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(
                    "You're all caught up!", 
                    style: GoogleFonts.notoRashiHebrew(fontSize: 24, fontWeight: FontWeight.w600, color: kBlack)
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Check back later for new profiles.", 
                    style: GoogleFonts.inter(fontSize: 14, color: kBlack.withOpacity(0.6))
                  ),
                ],
              )
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildHeader(context),
            ),
          ],
        ),
      );
    }"""
content = content.replace(empty_state_old, empty_state_new)


#### REPLACEMENT 2: Header ####
header_start = content.find("  Widget _buildHeader(BuildContext context) {")
header_end = content.find("  // --- ACTIONS ---")

if header_start != -1 and header_end != -1:
    new_header_code = """  Widget _buildHeader(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                kBgColor.withOpacity(0.95),
                kBgColor.withOpacity(0.6),
              ],
            ),
            border: Border(bottom: Border.all(color: kCardStroke.withOpacity(0.15), width: 1)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _showFiltersModal(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))
                    ]
                  ),
                  child: const Icon(Icons.tune_rounded, color: kBlack, size: 22),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildFilterChip('Age', () => _showFiltersModal()),
                    _buildFilterChip('Dating Intentions', () => _showFiltersModal()),
                    _buildFilterChip('Height', () => _showFiltersModal()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))
          ]
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kBlack.withOpacity(0.8),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down_rounded, color: kBlack.withOpacity(0.4), size: 18),
          ],
        ),
      ),
    );
  }

"""
    content = content[:header_start] + new_header_code + content[header_end:]


#### REPLACEMENT 3: Match Dialog ####
match_start = content.find("  void _showMatchDialog(Map<String, dynamic> profile) {")
match_end = content.find("  @override\n  Widget build(BuildContext context) {")

if match_start != -1 and match_end != -1:
    new_match = """  void _showMatchDialog(Map<String, dynamic> profile) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final photoUrl = (profile['photo_urls'] != null && (profile['photo_urls'] as List).isNotEmpty)
            ? profile['photo_urls'][0]
            : 'https://via.placeholder.com/150';

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: kBgColor,
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, 15))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("New Match!", 
                  style: GoogleFonts.notoRashiHebrew(color: kRose, fontSize: 32, fontWeight: FontWeight.w700)
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: kRose.withOpacity(0.3), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 70,
                    backgroundImage: NetworkImage(photoUrl),
                    backgroundColor: Colors.grey[200],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "You and ${profile['full_name']} liked each other.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 16, color: kBlack.withOpacity(0.7), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context), 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kRose,
                      foregroundColor: Colors.white,
                      shadowColor: kRose.withOpacity(0.5),
                      elevation: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: Text("Send a Message", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: kBlack.withOpacity(0.5),
                  ),
                  child: Text("Keep Swiping", style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

"""
    content = content[:match_start] + new_match + content[match_end:]


#### REPLACEMENT 4: _BouncingButton Class and _buildFloatingButtons ####
# We replace from _buildFloatingButtons down to _showFiltersModal
btn_start = content.find("  Widget _buildFloatingButtons() {")
btn_end = content.find("  // ================= REUSED WIDGETS =================")

if btn_start != -1 and btn_end != -1:
    new_btn = """  Widget _buildFloatingButtons() {
    if (_profiles.isEmpty) return const SizedBox();
    
    final currentProfileId = _profiles.first['id'].toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          // DISLIKE
          _BouncingButton(
            icon: Icons.close_rounded,
            bgColor: Colors.white,
            iconColor: kBlack,
            size: 70, 
            onTap: () => _onSwipe(currentProfileId, 'dislike'),
          ),
          const SizedBox(width: 24),
          // LIKE
          _BouncingButton(
            icon: Icons.favorite_rounded,
            bgColor: kRose, 
            iconColor: Colors.white,
            size: 70, 
            onTap: () => _onSwipe(currentProfileId, 'like'),
          ),
        ],
      ),
    );
  }

"""
    content = content[:btn_start] + new_btn + content[btn_end:]

# Replace bouncing button class completely
bclass_start = content.find("class _BouncingButton extends StatefulWidget {")
if bclass_start != -1:
    new_bclass = """class _BouncingButton extends StatefulWidget {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final double size;
  final VoidCallback onTap;

  const _BouncingButton({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.size,
    required this.onTap,
  });

  @override
  State<_BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<_BouncingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.bgColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.bgColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: widget.iconColor,
            size: widget.size * 0.45,
          ),
        ),
      ),
    );
  }
}
"""
    content = content[:bclass_start] + new_bclass

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("success")
