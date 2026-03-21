class ContentModerator {
  static String? validatePromptText(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    
    String lowerText = text.toLowerCase();

    // ==========================================
    // 1. THE ULTIMATE TELEGRAM DRAGNET
    // ==========================================
    
    // LAYER A: The Slang & Link Regex
    // This catches all the creative ways scammers write "tele me", "telid", "tg:", etc.
    final teleRegex = RegExp(
      r'\btelegram\b'               // The explicit word
      r'|\bt\s*\.\s*me\b'           // Catches: t.me, t . me
      r'|\b(tele|tg|tel)\s*(id)\b'  // Catches: teleid, tele id, telid, tel id, tgid, tg id
      r'|\b(tele|tg)\s*(me)\b'      // Catches: teleme, tele me, tgme, tg me (Avoids "tel me" typo for "tell me")
      r'|\b(tele|tg)[\s]*[:\-@]+'   // Catches: "tele:", "tg -", "tele @"
    );

    if (teleRegex.hasMatch(lowerText)) {
      return "Telegram handles and links are strictly prohibited.";
    }

    // LAYER B: The Sneaky Space Stripper
    // Scammers try to write "t e l e g r a m" or "t . m . e". This strips spaces/dots and catches them.
    String strippedText = lowerText.replaceAll(RegExp(r'[\s\.\-_]+'), '');
    if (strippedText.contains('telegram') || strippedText.contains('tme')) {
      return "Telegram handles and links are strictly prohibited.";
    }
    // ==========================================

    // 2. SMART PHONE NUMBER CATCHER
    // Translates trick letters (o->0) and strips formatting (spaces, dashes)
    String trickText = lowerText.replaceAll('o', '0').replaceAll('l', '1').replaceAll('s', '5');
    String compactText = trickText.replaceAll(RegExp(r'[\s\-\.\(\)\+]'), '');
    
    // Checks if there are 8 or more numbers mashed together
    if (RegExp(r'\d{8,}').hasMatch(compactText)) {
      return "Phone numbers are not allowed for safety reasons.";
    }

    // 3. ESCORT VOCABULARY & COMPETITOR PLATFORMS
    List<String> blockedWords = [
      'whatsapp', 'wa.me', 'tinder', 'bumble', 'onlyfans',
      'incall', 'outcall', 'ratecard', 'cashmeet', 'paytomeet', 'escort', 'hookup'
    ];
    
    for (String word in blockedWords) {
      if (lowerText.contains(word)) {
        return "This content violates our community guidelines.";
      }
    }

    // If it makes it here, the text is completely safe.
    // Handles like "@srujxn.18" or "ig: rahul99" will easily pass!
    return null; 
  }
}
