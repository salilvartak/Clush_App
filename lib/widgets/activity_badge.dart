import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clush/theme/colors.dart';

enum _ActivityLevel { activeNow, activeToday, activeYesterday, activeLongAgo }

class ActivityBadge extends StatelessWidget {
  final String? lastSeenAt;
  final bool compact; // true = dot only, false = dot + text

  const ActivityBadge({super.key, required this.lastSeenAt, this.compact = false});

  static _ActivityLevel _level(DateTime? t) {
    if (t == null) return _ActivityLevel.activeLongAgo;
    final now = DateTime.now().toUtc();
    final diff = now.difference(t);
    if (diff.inMinutes < 5) return _ActivityLevel.activeNow;
    final today = DateTime.utc(now.year, now.month, now.day);
    final tDay = DateTime.utc(t.year, t.month, t.day);
    if (tDay == today) return _ActivityLevel.activeToday;
    if (today.difference(tDay).inDays == 1) return _ActivityLevel.activeYesterday;
    return _ActivityLevel.activeLongAgo;
  }

  static String _label(_ActivityLevel level, DateTime? t) {
    switch (level) {
      case _ActivityLevel.activeNow:
        return 'Active now';
      case _ActivityLevel.activeToday:
        return 'Active today';
      case _ActivityLevel.activeYesterday:
        return 'Active yesterday';
      case _ActivityLevel.activeLongAgo:
        if (t == null) return 'Offline';
        // e.g. "Active Apr 1"
        final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        return 'Active ${months[t.month - 1]} ${t.day}';
    }
  }

  static Color _color(_ActivityLevel level) {
    switch (level) {
      case _ActivityLevel.activeNow:
        return const Color(0xFF4CAF50); // green
      case _ActivityLevel.activeToday:
        return const Color(0xFFFFC107); // amber
      default:
        return kInkMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime? t;
    if (lastSeenAt != null) {
      try { t = DateTime.parse(lastSeenAt!).toUtc(); } catch (_) {}
    }
    final level = _level(t);
    final color = _color(level);

    if (compact) {
      // Just the dot (for list tiles / avatars)
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          _label(level, t),
          style: GoogleFonts.figtree(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color == kInkMuted ? kInkMuted : color,
          ),
        ),
      ],
    );
  }
}
