class ContentModerator {
  static String? validateText(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    
    String lowerText = text.toLowerCase();

    // 1. THE WILDCARD CATCHER
    // Catches underscores, @username, ©username, AND words ending in numbers
    final RegExp wildcardRegex = RegExp(r'[@©]\S+|ig:\s*\S+|snap:\s*\S+|\S*_\S*|[a-z]+\d{2,}');
    if (wildcardRegex.hasMatch(lowerText)) {
      return "Social media handles, usernames, and contact info are not allowed.";
    }

    // 2. LEET-SPEAK DECODER
    final Map<String, String> replacements = {
      '@': 'a', '4': 'a', '3': 'e', '1': 'i', '!': 'i', 
      '0': 'o', '5': 's', '\$': 's', '8': 'b', '7': 't', '(': 'c'
    };
    String decodedText = lowerText;
    replacements.forEach((key, value) { 
      decodedText = decodedText.replaceAll(key, value); 
    });

    // 3. STRIP TEXT
    final strippedText = decodedText.replaceAll(RegExp(r'[\s\W_]+'), '');

    // 4. BLOCKED PLATFORMS
    final blockedPlatforms = ['telegram', 'snapchat', 'tme', 'instagram'];
    for (var p in blockedPlatforms) { 
      if (strippedText.contains(p)) {
        return "Mentions of external messaging apps are strictly prohibited."; 
      }
    }

    // 5. SCAM & ESCORT WORDS
    final scamKeywords = [
      'incall', 'outcall', 'paidservice', 'hourlyrate', 'cashmeet', 
      'escort', 'gfe', 'hookup', 'paytomeet', 'rates', 'serviceavailable', 
      'paidsx', 'ratecard'
    ];
    for (var w in scamKeywords) { 
      if (strippedText.contains(w)) {
        return "Your profile violates our community safety guidelines."; 
      }
    }

    if (RegExp(r'(ghost app|paper plane|blue app|camera app|yellow app)').hasMatch(decodedText)) {
      return "Using nicknames for external social apps is not allowed.";
    }

    // 6. NUMBER WORDS COUNTER
    final numberWords = [
      'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 
      'shunya', 'ek', 'do', 'teen', 'chaar', 'char', 'paanch', 'panch', 'che', 'chah', 
      'saat', 'sat', 'aath', 'ath', 'nau', 'no'
    ];
    int count = 0;
    for (var word in numberWords) { 
      if (RegExp(r'\b' + word + r'\b').hasMatch(lowerText)) count++; 
    }
    if (count >= 7) return "Spelling out phone numbers is not allowed.";

    // 7. PHONE SCANNER
    String digitCheckText = lowerText.replaceAll('o', '0').replaceAll('l', '1').replaceAll('s', '5');
    if (digitCheckText.replaceAll(RegExp(r'\D'), '').length >= 8 && digitCheckText.replaceAll(RegExp(r'\D'), '').length <= 15) {
      return "Phone numbers are not allowed.";
    }

    // 8. SOCIAL SLANG
    if (RegExp(r'\b(tg|sc|ig|tele|snap|insta)\b').hasMatch(decodedText)) {
      return "Please remove social media abbreviations.";
    }

    return null; // Passed all checks!
  }
}
