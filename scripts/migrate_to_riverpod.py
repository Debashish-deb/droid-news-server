#!/usr/bin/env python3
"""
Automated Provider to Riverpod Migration Script
Migrates legacy ThemeProvider usage to Riverpod consistently
"""

import re
import os

# File paths to migrate
FILES_TO_MIGRATE = [
    "lib/features/quiz/daily_quiz_widget.dart",
    "lib/features/profile/profile_screen.dart",
    "lib/features/history/history_widget.dart",
    "lib/features/common/animated_background.dart",
    "lib/features/news_detail/animated_background.dart",
    "lib/features/news/newspaper_screen.dart",
    "lib/features/magazine/magazine_screen.dart",
    "lib/features/magazine/widgets/magazine_card.dart",
    "lib/features/news_detail/news_detail_screen.dart",
    "lib/features/profile/animated_background.dart",
]

def migrate_file(filepath):
    """Migrate a single file from Provider to Riverpod"""
    
    with open(filepath, 'r') as f:
        content = f.read()
    
    original = content
    
    # 1. Add Riverpod import if not present
    if 'flutter_riverpod' not in content:
        # Find the last import
        imports = re.findall(r'^import .*?;$', content, re.MULTILINE)
        if imports:
            last_import = imports[-1]
            content = content.replace(
                last_import,
                last_import + "\nimport 'package:flutter_riverpod/flutter_riverpod.dart';"
            )
    
    # 2. Add theme_providers import if not present
    if 'presentation/providers/theme_providers.dart' not in content:
        imports = re.findall(r'^import .*?;$', content, re.MULTILINE)
        if imports:
            last_import = imports[-1]
            content = content.replace(
                last_import,
                last_import + "\nimport '../../../presentation/providers/theme_providers.dart';"
            )
    
    # 3. Ensure AppThemeMode import (from theme_provider.dart)
    if 'AppThemeMode' in content and 'core/theme_provider.dart' not in content:
        imports = re.findall(r'^import .*?;$', content, re.MULTILINE)
        if imports:
            last_import = imports[-1]
            content = content.replace(
               last_import,
                last_import + "\nimport '../../../core/theme_provider.dart'; // For AppThemeMode enum"
            )
    
    # 4. Convert StatelessWidget to ConsumerWidget
    content = re.sub(
        r'class (\w+) extends StatelessWidget',
        r'class \1 extends ConsumerWidget',
        content
    )
    
    # 5. Update build method signature
    content = re.sub(
        r'Widget build\(BuildContext context\)',
        r'Widget build(BuildContext context, WidgetRef ref)',
        content
    )
    
    # 6. Replace Provider.of<ThemeProvider> with Riverpod
    content = re.sub(
        r'final\s+ThemeProvider\s+(\w+)\s*=\s*provider\.Provider\.of<ThemeProvider>\(context(?:,\s*listen:\s*\w+)?\);',
        r'// Migrated to Riverpod\n    final AppThemeMode themeMode = ref.watch(currentThemeModeProvider);',
        content
    )
    
    content = re.sub(
        r'final\s+ThemeProvider\s+(\w+)\s*=\s*Provider\.of<ThemeProvider>\(context(?:,\s*listen:\s*\w+)?\);',
        r'// Migrated to Riverpod\n    final AppThemeMode themeMode = ref.watch(currentThemeModeProvider);',
        content
    )
    
    # 7. Replace prov.appThemeMode or themeProv.appThemeMode with themeMode
    content = re.sub(r'\bprov\.appThemeMode\b', 'themeMode', content)
    content = re.sub(r'\bthemeProv\.appThemeMode\b', 'themeMode', content)
    
    # 8. Replace prov.isDark or themeProv.isDark
    content = re.sub(
        r'\b(prov|themeProv)\.isDark\b',
        '(themeMode == AppThemeMode.dark || themeMode == AppThemeMode.amoled)',
        content
    )
    
    # 9. Replace prov.glassColor with ref.watch(glassColorProvider)
    content = re.sub(r'\bprov\.glassColor\b', 'ref.watch(glassColorProvider)', content)
    content = re.sub(r'\bthemeProv\.glassColor\b', 'ref.watch(glassColorProvider)', content)
    
    # Only write if changed
    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        return True
    return False

if __name__ == "__main__":
    base_dir = "/Users/debashishdeb/Documents/JS/MobileApp/droid"
    
    migrated = []
    for file in FILES_TO_MIGRATE:
        filepath = os.path.join(base_dir, file)
        if os.path.exists(filepath):
            if migrate_file(filepath):
                migrated.append(file)
                print(f"✅ Migrated: {file}")
            else:
                print(f"⏭️  Skipped (no changes): {file}")
        else:
            print(f"❌ Not found: {file}")
    
    print(f"\n📊 Summary: {len(migrated)}/{len(FILES_TO_MIGRATE)} files migrated")
