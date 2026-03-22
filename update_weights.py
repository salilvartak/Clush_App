import os, glob, re

replacements_done = 0

def replace_in_file(filepath):
    global replacements_done
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content
    filename = os.path.basename(filepath)
    
    # Update Gabarito font weights to bold
    # Let's find all GoogleFonts.gabarito(...) calls.
    # We replace any `fontWeight: FontWeight.w\d00` or `fontWeight: FontWeight.normal` with `fontWeight: FontWeight.bold`
    content = re.sub(r'(GoogleFonts\.gabarito\([^\)]*?fontWeight:\s*FontWeight\.)w\d00', r'\1bold', content)
    content = re.sub(r'(GoogleFonts\.gabarito\([^\)]*?fontWeight:\s*FontWeight\.)normal', r'\1bold', content)
    
    # If Gabarito doesn't have fontWeight, we should add it? 
    # Let's just do a simpler search and replace for specific known issues, or replace GoogleFonts.gabarito( with GoogleFonts.gabarito(fontWeight: FontWeight.bold,
    # actually sometimes it already has it. So let's first strip existing fontWeights, then add bold:
    
    def add_bold_to_gabarito(match):
        inner = match.group(1)
        # remove existing fontWeight
        inner = re.sub(r'fontWeight:\s*FontWeight\.\w+,?\s*', '', inner)
        return f'GoogleFonts.gabarito(fontWeight: FontWeight.bold, {inner}'
        
    content = re.sub(r'GoogleFonts\.gabarito\((.*?)\)', add_bold_to_gabarito, content, flags=re.DOTALL)
    
    # For prompt questions in discover_page.dart, edit_profile_page.dart, profile_view_page.dart
    # They look like prompt['question'] followed by GoogleFonts.figtree(..., fontWeight: FontWeight.w600
    if filename in ['discover_page.dart', 'profile_view_page.dart', 'edit_profile_page.dart']:
        content = re.sub(r'(prompt\[\Wquestion\W\].*?GoogleFonts\.figtree\([^\)]*?fontWeight:\s*FontWeight\.)w\d00',
                         r'\1bold', content, flags=re.DOTALL)

    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        replacements_done += 1
        print(f"Updated {filepath}")

dart_files = glob.glob('lib/**/*.dart', recursive=True)
for f in dart_files:
    replace_in_file(f)

print(f'Modified {replacements_done} files.')
