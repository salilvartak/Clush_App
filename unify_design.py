import glob, re, os

# Mapping of generic Material colors to our custom palette
# We avoid replacing Colors.white indiscriminately because it might be text on a primary button.
# But we can replace specific ones easily.

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content
    filename = os.path.basename(filepath)

    # 1. Standardize Shadows
    # Old shadows might be Colors.black.withOpacity(0.04) or similar.
    # The standard is kInk.withOpacity(0.06) or 0.1 for deeper ones.
    content = re.sub(r'Colors\.black\.withOpacity\((0\.\d+)\)', r'kInk.withOpacity(\1)', content)
    
    # 2. Border colors
    # Grey borders -> kBone
    content = re.sub(r'Colors\.grey\.shade[0-9]+', 'kBone', content)
    
    # 3. Text colors
    # Black variants -> kInk or kInkMuted
    content = re.sub(r'Colors\.black87', 'kInk', content)
    content = re.sub(r'Colors\.black54', 'kInkMuted', content)
    content = re.sub(r'Colors\.black45', 'kInkMuted', content)
    content = re.sub(r'Colors\.black38', 'kInkMuted', content)
    content = re.sub(r'Colors\.black26', 'kBone', content)
    content = re.sub(r'Colors\.black12', 'kBone', content)
    
    # Just Colors.black as well (except inside withOpacity which we caught above)
    content = re.sub(r'(?<!\.)Colors\.black(?![\.\w])', 'kInk', content)
    content = re.sub(r'(?<!\.)Colors\.grey(?![\.\w])', 'kInkMuted', content)

    # 4. Standardizing UI Containers
    # Replace white backgrounds with kParchment or kCream for container elements.
    # We will replace `color: Colors.white` with `color: kParchment` mostly in BoxDecorations and scaffold backgrounds
    # Wait, some places just have `Colors.white` directly. 
    # Let's see if we can safely replace `Colors.white` inside `BoxDecoration(color: Colors.white` with `kParchment`
    content = re.sub(r'BoxDecoration\(\s*color:\s*Colors\.white', r'BoxDecoration(color: kParchment', content)
    
    # Scaffold backgrounds from Colors.white to kCream
    content = re.sub(r'backgroundColor:\s*Colors\.white', r'backgroundColor: kCream', content)

    # 5. Fix `TextStyle(...)` to use `GoogleFonts.figtree(...)` or `GoogleFonts.dmSans(...)`?
    # Actually ThemeData already uses figtree as default. But inline `TextStyle` can remain since it inherits the theme. 
    # That is perfectly fine.

    # 6. Add the import for colors if it's missing but we used a 'k' color
    if 'kInk' in content or 'kBone' in content or 'kParchment' in content or 'kCream' in content:
        if 'theme/colors.dart' not in content and 'import' in content:
            # add import right after the last import
            last_import_index = content.rfind("import '")
            if last_import_index != -1:
                end_of_line = content.find(";", last_import_index)
                content = content[:end_of_line+1] + "\nimport 'theme/colors.dart';" + content[end_of_line+1:]

    # 7. Unify Border Radius
    # Mostly replace BorderRadius.circular(24.0) -> BorderRadius.circular(20)
    # Actually, 20 is standard for cards. 24 is close enough, but let's make it 20.
    content = re.sub(r'BorderRadius\.circular\((?:24(?:\.0)?|16(?:\.0)?|12(?:\.0)?)\)', r'BorderRadius.circular(20)', content)

    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Unified design in {filepath}")

for f in glob.glob('lib/**/*.dart', recursive=True):
    process_file(f)
