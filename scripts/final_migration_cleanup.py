#!/usr/bin/env python3
"""
Final cleanup script for remaining migration errors
"""
import re
import os

BASE = "/Users/debashishdeb/Documents/JS/MobileApp/droid"

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    orig = content
    
    # Fix 1: Remove duplicate themeMode definitions
    # Pattern: two consecutive themeMode definitions
    content = re.sub(
        r'(final AppThemeMode themeMode = ref\.watch\(currentThemeModeProvider\);)\s*\n\s*final AppThemeMode themeMode = ref\.watch\(currentThemeModeProvider\);',
        r'\1',
        content
    )
    
    # Fix 2: Remove themeProv references that weren't caught
    content = re.sub(r'themeProv\.', 'themeMode.', content)
    
    # Fix 3: Fix ConsumerConsumerState typo
    content = re.sub(r'ConsumerConsumerState<', r'ConsumerState<', content)
    
    # Fix 4: Fix nested build methods with extra themeMode
    # Remove themeMode from nested Widget builders
    content = re.sub(
        r'(@override\s+Widget build\(BuildContext context\)\s\{\s*final AppThemeMode themeMode = ref\.watch\(currentThemeModeProvider\);)\s*\n\s*final AppThemeMode themeMode',
        r'\1\n    final bool isDark',
        content
    )
    
    # Fix 5: In quiz widget, ensure themeMode is available in all builder methods
    # Replace remaining undefined themeMode with ref.watch
    if 'daily_quiz_widget.dart' in filepath:
        # Fix builder methods that reference themeMode without defining it
        content = re.sub(
            r'(Widget\s+_\w+\([^)]*\)\s*\{(?!\s*final AppThemeMode))',
            r'\1\n    final AppThemeMode themeMode = ref.watch(currentThemeModeProvider);',
            content
        )
    
    if content != orig:
        with open(filepath, 'w') as f:
            f.write(content)
        return True
    return False

# Files with errors
ERROR_FILES = [
    "lib/features/common/animated_background.dart",
    "lib/features/history/history_widget.dart",
    "lib/features/magazine/magazine_screen.dart",
    "lib/features/magazine/widgets/magazine_card.dart",
    "lib/features/news/newspaper_screen.dart",
    "lib/features/news_detail/animated_background.dart",
    "lib/features/news_detail/news_detail_screen.dart",
    "lib/features/profile/profile_screen.dart",
    "lib/features/quiz/daily_quiz_widget.dart",
]

if __name__ == "__main__":
    for file in ERROR_FILES:
        path = os.path.join(BASE, file)
        if os.path.exists(path):
            if fix_file(path):
                print(f"✅ {file}")
            else:
                print(f"⏭️  {file}")
