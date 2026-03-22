import os, glob, re

replacements_done = 0

def replace_in_file(filepath):
    global replacements_done
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content
    filename = os.path.basename(filepath)
    
    # settings pages use Montserrat
    if 'setting' in filename.lower():
        content = re.sub(r'GoogleFonts\.domine\b', 'GoogleFonts.montserrat', content)
        content = re.sub(r'GoogleFonts\.dmSans\b', 'GoogleFonts.montserrat', content)
    else:
        # Globally replace dmSans with figtree (basic info, text, etc)
        content = re.sub(r'GoogleFonts\.dmSansTextTheme\b', 'GoogleFonts.figtreeTextTheme', content)
        content = re.sub(r'GoogleFonts\.dmSans\b', 'GoogleFonts.figtree', content)
        
        # Globally replace domine with gabarito (for headings, names)
        content = re.sub(r'GoogleFonts\.domine\b', 'GoogleFonts.gabarito', content)
        
        # Prompt answers should be Ledger instead of Gabarito
        # In _buildPromptCard for example:
        content = re.sub(r'(prompt\[\'answer\'\].*?style:\s*GoogleFonts\.)gabarito',
                         r'\1ledger', content, flags=re.DOTALL)
                         
    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        replacements_done += 1
        print(f"Updated {filepath}")

dart_files = glob.glob('lib/**/*.dart', recursive=True)
for f in dart_files:
    replace_in_file(f)

print(f'Modified {replacements_done} files.')
