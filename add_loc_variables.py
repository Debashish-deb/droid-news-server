#!/usr/bin/env python3
"""Add AppLocalizations loc variable to build methods"""
import re

files_to_fix = [
    "lib/features/common/webview_screen.dart",
    "lib/features/help/help_screen.dart",
    "lib/features/history/history_widget.dart",
    "lib/features/quiz/daily_quiz_widget.dart",
]

def add_loc_to_build_method(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    original = content
    
    # Find build methods that use 'loc.' but don't define it
    if 'loc.' in content and 'final AppLocalizations loc =' not in content and 'final loc =' not in content:
        # Find Widget build( method
        build_pattern = r'(Widget build\(BuildContext context(?:, WidgetRef ref)?\) \{)'
        
        match = re.search(build_pattern, content)
        if match:
            # Insert loc declaration right after the build method opening
            insert_pos = match.end()
            loc_declaration = '\n    final AppLocalizations loc = AppLocalizations.of(context)!;'
            content = content[:insert_pos] + loc_declaration + content[insert_pos:]
            print(f"✅ Added 'loc' variable to {filepath}")
        else:
            # Try finding in _build methods (private methods)
            private_build_pattern = r'(Widget _build\w+\((?:BuildContext context)?\) \{)'
            matches = list(re.finditer(private_build_pattern, content))
            if matches:
                # Add to first one that needs it
                insert_pos = matches[0].end()
                loc_declaration = '\n    final AppLocalizations loc = AppLocalizations.of(context)!;'
                content = content[:insert_pos] + loc_declaration + content[insert_pos:]
                print(f"✅ Added 'loc' variable to private method in {filepath}")
    
    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        return True
    return False

print("🔧 Adding AppLocalizations loc variables...\n")

for filepath in files_to_fix:
    add_loc_to_build_method(filepath)

print("\n✨ Done!")
