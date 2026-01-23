#!/usr/bin/env python3
"""Final comprehensive fix for all remaining compilation errors"""
import re

# Fix quiz widget - remove all ref.watch and prov references,get theme via Provider
def fix_quiz_widget():
    filepath = "lib/features/quiz/daily_quiz_widget.dart"
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Remove all ref.watch(currentThemeModeProvider) since it's StatefulWidget
    content = re.sub(
        r'final themeMode = ref\.watch\(currentThemeModeProvider\);',
        '// Theme handled via Provider below',
        content
    )
    
    # Replace prov.appThemeMode with getting it from Provider
    # Add ThemeProvider import if missing
    if 'ThemeProvider' not in content:
        content = re.sub(
            r"(import 'package:flutter/material.dart';)",
            r"\1\nimport 'package:provider/provider.dart';\nimport '../../core/theme_provider.dart';",
            content
        )
    
    # For each build method that has prov.appThemeMode, add Provider.of
    # Pattern: prov.appThemeMode ==
    lines = content.split('\n')
    fixed_lines = []
    in_build_method = False
    added_provider = False
    
    for i, line in enumerate(lines):
        # Detect build method start
        if 'Widget build(BuildContext context)' in line:
            in_build_method = True
            added_provider = False
        
        # If in build and we see prov.appThemeMode and haven't added provider yet
        if in_build_method and 'prov.appThemeMode' in line and not added_provider:
            # Insert provider fetch before this line
            indent = len(line) - len(line.lstrip())
            provider_line = ' ' * indent + 'final themeProv = Provider.of<ThemeProvider>(context);'
            fixed_lines.append(provider_line)
            added_provider = True
            # Replace prov with themeProv
            line = line.replace('prov.appThemeMode', 'themeProv.appThemeMode')
            line = line.replace('prov.', 'themeProv.')
        elif 'prov.' in line:
            line = line.replace('prov.', 'themeProv.')
        
        # Reset when leaving method
        if in_build_method and line.strip().startswith('}') and line.count('}') >= line.count('{'):
            in_build_method = False
        
        fixed_lines.append(line)
    
    content = '\n'.join(fixed_lines)
    
    with open(filepath, 'w') as f:
        f.write(content)
    
    print(f"✅ Fixed quiz_widget.dart")

# Fix animated background files
def fix_animated_backgrounds():
    files = [
        "lib/features/common/animated_background.dart",
        "lib/features/news_detail/animated_background.dart"
    ]
    
    for filepath in files:
        try:
            with open(filepath, 'r') as f:
                content = f.read()
            
            # Fix Provider ambiguity
            if "import 'package:provider/provider.dart';" in content and "import 'package:riverpod" in content:
                content = content.replace(
                    "import 'package:provider/provider.dart';",
                    "import 'package:provider/provider.dart' as provider;"
                )
                content = content.replace(
                    'Provider.of<ThemeProvider>',
                    'provider.Provider.of<ThemeProvider>'
                )
            
            # Fix theme.isDark to themeProv.isDark
            content = content.replace('if (theme.isDark)', 'if (themeProv.isDark)')
            
            #Fix undefined theme variable
            content = re.sub(
                r'_resolveGradient\(theme\)',
                r'_resolveGradient(themeProv)',
                content
            )
            
            # Fix themeMode references in news_detail version
            if 'themeMode ==' in content:
                content = re.sub(
                    r'\(themeMode == AppThemeMode\.dark \|\| themeMode == AppThemeMode\.amoled \|\| themeMode == AppThemeMode\.bangladesh\)Mode\)',
                    r'themeProv.isDark',
                    content
                )
            
            with open(filepath, 'w') as f:
                f.write(content)
            
            print(f"✅ Fixed {filepath}")
        except Exception as e:
            print(f"⚠️  Error fixing {filepath}: {e}")

# Fix history widget Provider ambiguity
def fix_history_widget():
    filepath = "lib/features/history/history_widget.dart"
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Add provider prefix if both packages imported
    if "import 'package:provider/provider.dart';" in content and "import 'package:riverpod" in content:
        if " as provider;" not in content:
            content = content.replace(
                "import 'package:provider/provider.dart';",
                "import 'package:provider/provider.dart' as provider;"
            )
            content = content.replace(
                'Provider.of<ThemeProvider>',
                'provider.Provider.of<ThemeProvider>'
            )
    
    with open(filepath, 'w') as f:
        f.write(content)
    
    print(f"✅ Fixed history_widget.dart")

# Fix professional header
def fix_professional_header():
    filepath = "lib/features/home/widgets/professional_header.dart"
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Replace prov.appThemeMode with themeMode
    content = content.replace('prov.appThemeMode', 'themeMode')
    
    with open(filepath, 'w') as f:
        f.write(content)
    
    print(f"✅ Fixed professional_header.dart")

print("🔧 Running final comprehensive fixes...\n")

fix_quiz_widget()
fix_animated_backgrounds()
fix_history_widget()
fix_professional_header()

print("\n✨ All fixes applied!")
print("Running flutter analyze to check error count...")
