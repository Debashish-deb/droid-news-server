#!/usr/bin/env python3
"""Fix loc variable placement in StatefulWidget build methods"""
import re

def fix_stateful_widget_loc(filepath):
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    # Find StatefulWidget build methods and add loc right after opening brace
    fixed_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        fixed_lines.append(line)
        
        # Check if this is a build method in StatefulWidget
        if re.match(r'\s+@override\s*$', line.strip()):
            # Next line should be Widget build
            if i + 1 < len(lines) and 'Widget build(BuildContext context)' in lines[i + 1]:
                # Add the build line
                i += 1
                fixed_lines.append(lines[i])
                
                # Next should be opening brace, add loc after it
                if i + 1 < len(lines) and '{' in lines[i + 1]:
                    i += 1
                    fixed_lines.append(lines[i])
                    # Add loc variable if uses loc. and doesn't already have it
                    if i + 1 < len(lines) and 'final AppLocalizations loc' not in lines[i + 1]:
                        indent = len(lines[i]) - len(lines[i].lstrip())
                        fixed_lines.append(' ' * (indent + 4) + 'final AppLocalizations loc = AppLocalizations.of(context)!;\n')
                        print(f"✅ Added loc to build method in {filepath}")
        
        i += 1
    
    with open(filepath, 'w') as f:
        f.writelines(fixed_lines)

files = [
    "lib/features/common/webview_screen.dart",
    "lib/features/history/history_widget.dart", 
    "lib/features/quiz/daily_quiz_widget.dart",
]

print("🔧 Fixing loc variables in StatefulWidgets...\n")
for f in files:
    try:
        fix_stateful_widget_loc(f)
    except Exception as e:
        print(f"❌ Error fixing {f}: {e}")

print("\n✨ Done!")
