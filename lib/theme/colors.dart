import 'package:flutter/material.dart';

// ─── BOUTIQUE CLUB PALETTE ────────────────────────────────────────────────────

// Screen backgrounds
const Color kBackground = Color(0xFFFCF9F8); // Warm Cream — all screen backgrounds
const Color kCream      = kBackground;        // alias

// Card / panel backgrounds
const Color kCard       = Color(0xFFFFFFFF);  // Pure White — profile cards, setting panels
const Color kParchment  = kCard;              // alias
const Color kTan        = kCard;              // alias

// Deep Emerald — CTA buttons, active heart, accent states
const Color kAccent   = Color(0xFF1A2C26);
const Color kPrimary  = kAccent;              // alias

// Body text / headings (slightly lighter green-grey)
const Color kInk   = Color(0xFF000000);
const Color kBlack = kInk;                   // alias

// Premium accent (Champagne Gold) — lightning bolt, verified ticks, selected states
const Color kGold = Color(0xFFD4AF37);

// Secondary text — subtext, timestamps, unselected tags (Muted Green-Grey)
const Color kSecondaryText = Color(0xFF424242);
const Color kInkMuted      = kSecondaryText;  // alias
const Color kInkSecondary  = kSecondaryText;  // alias

// Borders & separators (1 px everywhere)
const Color kBorderLight = Color(0xFFE5E7EB);
const Color kBone        = kBorderLight;      // alias

// Tag / chip background — slightly darker cream
const Color kTagBg = Color(0xFFF0EDE6);

// Interest chip / discover page background — soft sage mint
const Color kChipBg = Color(0xFFE5F0EC);

// Destructive / error
const Color kDestructive = Color(0xFFA84A4A);

// ─── LEGACY — kept so untouched files compile ─────────────────────────────────
// These were the old rose-themed accent colours.  Do NOT use in new/refactored code.
const Color kRose      = Color(0xFF1A2C26);
const Color kRoseLight = Color(0xFF1A2C26);
const Color kRosePale  = Color(0xFFF3E8E3);
