#!/usr/bin/env python3
"""Final definitive fix - proper Provider prefixing and syntax fixes"""
import os
import re

def add_provider_prefix_to_file(filepath):
    """Add 'provider.' prefix to Provider.of calls and fix import"""
    if not os.path.exists(filepath):
        return False
    
    with open(filepath, 'r') as f:
        content = f.read()
    
    original = content
    
    # Check if both provider and riverpod are imported
    has_provider = 'package:provider/provider.dart' in content
    has_riverpod = 'package:riverpod' in content
    
    if has_provider and has_riverpod:
        # Ensure provider package is prefixed
        if "import 'package:provider/provider.dart';" in content and ' as provider;' not in content:
            content = content.replace(
                "import 'package:provider/provider.dart';",
                "import 'package:provider/provider.dart' as provider;"
            )
        
        # Prefix all Provider.of calls
        content = re.sub(
            r'(\s+)Provider\.of<',
            r'\1provider.Provider.of<',
            content
        )
        
        # Also fix any missed ones
        content = content.replace('final prov = Provider.of<', 'final prov = provider.Provider.of<')
        content = content.replace('final themeProv = Provider.of<', 'final themeProv = provider.Provider.of<')
        content = content.replace('final ThemeProvider themeProv = Provider.of<', 'final ThemeProvider themeProv = provider.Provider.of<')
    
    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        return True
    return False

files_to_fix = [
    "lib/features/news/newspaper_screen.dart",
    "lib/features/magazine/magazine_screen.dart",
    "lib/features/news_detail/news_detail_screen.dart",
    "lib/features/news/widgets/news_card.dart",
    "lib/features/magazine/widgets/magazine_card.dart",
    "lib/features/history/history_widget.dart",
    "lib/features/quiz/daily_quiz_widget.dart",
    "lib/features/common/animated_background.dart",
    "lib/features/news_detail/animated_background.dart",
]

print("🔧 Applying definitive Provider prefix fixes...\n")

for filepath in files_to_fix:
    if add_provider_prefix_to_file(filepath):
        print(f"✅ {filepath}")

print("\n✨ Provider prefixing complete!")
