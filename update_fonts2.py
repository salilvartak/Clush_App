import os, glob, re

replacements_done = 0

def replace_in_file(filepath):
    global replacements_done
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content
    filename = os.path.basename(filepath)
    
    # Montserrat for settings pages
    if 'setting' in filename.lower():
        content = re.sub(r'GoogleFonts\.domine\b', 'GoogleFonts.montserrat', content)
        content = re.sub(r'GoogleFonts\.dmSans\b', 'GoogleFonts.montserrat', content)
    else:
        # We replace dmSansTextTheme -> figtreeTextTheme
        content = re.sub(r'GoogleFonts\.dmSansTextTheme\b', 'GoogleFonts.figtreeTextTheme', content)
        
        # Replace dmSans -> figtree everywhere else. 
        # (This handles the 'basic information about a user on the discover page')
        content = re.sub(r'GoogleFonts\.dmSans\b', 'GoogleFonts.figtree', content)
        
        # Replace domine -> gabarito (for headings, names, etc.)
        content = re.sub(r'GoogleFonts\.domine\b', 'GoogleFonts.gabarito', content)
        
        # "Gabarito: page heading and names of users in bold."
        # This means EVERY gabarito should have fontWeight: FontWeight.bold.
        # So we'll find all `GoogleFonts.gabarito(` and make sure it sets fontWeight: FontWeight.bold.
        # But we must avoid breaking syntax! 
        # The easiest way is to look for `GoogleFonts.gabarito(` and inject `fontWeight: FontWeight.bold, ` right after it, 
        # but also strip any existing `fontWeight: [^,)]+,?` inside it.
        # Wait, parsing parentheses in regex is dangerous as we saw.
        # Let's just find `GoogleFonts.gabarito(` and manually process string by matching brackets.
        
        parts = content.split('GoogleFonts.gabarito(')
        for i in range(1, len(parts)):
            # We want to remove any existing fontWeight inside this gabarito call.
            # Just do a simple regex on the rest of the string up to the FIRST `)` 
            # Note: what if there are nested parentheses like `color: kRose.withOpacity(0.3)`?
            # We must parse brackets.
            depth = 1
            idx = 0
            while idx < len(parts[i]) and depth > 0:
                if parts[i][idx] == '(':
                    depth += 1
                elif parts[i][idx] == ')':
                    depth -= 1
                idx += 1
            
            # idx is now right after the matching ')'
            inner_args = parts[i][:idx-1]
            rest = parts[i][idx-1:]
            
            # remove existing fontWeight: ... from inner_args
            inner_args = re.sub(r'fontWeight:\s*FontWeight\.[a-zA-Z0-9_]+,?\s*', '', inner_args)
            
            # add fontWeight: FontWeight.bold
            inner_args = 'fontWeight: FontWeight.bold, ' + inner_args.lstrip()
            
            parts[i] = inner_args + rest
            
        content = 'GoogleFonts.gabarito('.join(parts)
        
        # "Ledger-----prompt answers larger font than others"
        # We know prompt answers are: prompt['answer']
        # The current font is GoogleFonts.gabarito( ... ) after our replace above.
        # We must change it to GoogleFonts.ledger(
        if filename in ['discover_page.dart', 'profile_view_page.dart', 'edit_profile_page.dart']:
            # The prompt card builds it like this:
            # Text(
            #   prompt['answer'],
            #   style: GoogleFonts.gabarito(
            content = re.sub(r'(prompt\[\'answer\'\],?\s*style:\s*GoogleFonts\.)gabarito', r'\1ledger', content)
            
            # "Figtree: ... and also for prompt questions but bold"
            # Text(
            #   prompt['question'] as String,
            #   style: GoogleFonts.figtree(
            # We need to ensure it's bold.
            
            content = re.sub(r'(prompt\[\'question\'\]\s*as\s*String,?\s*style:\s*GoogleFonts\.figtree\([^)]*?fontWeight:\s*FontWeight\.)w\w+', r'\1bold', content)
            
            # If not using fontWeight, add it. The existing code uses w600 which will be replaced by bold above.

    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        replacements_done += 1
        print(f"Updated {filepath}")

dart_files = glob.glob('lib/**/*.dart', recursive=True)
for f in dart_files:
    replace_in_file(f)

print(f'Modified {replacements_done} files.')
