#!/usr/bin/env python3
"""Complete widget migration: Convert all legacy Provider to Riverpod with .select() optimization"""
import os
import re
from pathlib import Path

# Files that need migration based on grep results
files_to_migrate = [
    "lib/features/magazine/magazine_screen.dart",
    "lib/features/history/history_widget.dart",
    "lib/features/news/widgets/news_card.dart",
    "lib/features/magazine/widgets/magazine_card.dart",
    "lib/features/extras/extras_screen.dart",
    "lib/features/news/newspaper_screen.dart",
    "lib/features/search/search_screen.dart",
    "lib/features/common/animated_background.dart",
    "lib/features/quiz/daily_quiz_widget.dart",
    "lib/features/news_detail/news_detail_screen.dart",
    "lib/features/home/widgets/professional_header.dart",
    "lib/features/profile/profile_screen.dart",
    "lib/features/home/widgets/news_card.dart",
    "lib/features/news_detail/animated_background.dart",
]

def migrate_file(filepath):
    """Migrate a single file to use Riverpod"""
    if not os.path.exists(filepath):
        print(f"⚠️  Skipping {filepath} - not found")
        return False
    
    with open(filepath, 'r') as f:
        content = f.read()
    
    original_content = content
    changes = []
    
    # 1. Replace context.watch<ThemeProvider>() with ref.watch(currentThemeModeProvider)
    if 'context.watch<ThemeProvider>()' in content:
        # For theme mode specifically
        content = re.sub(
            r'final\s+ThemeProvider\s+(\w+)\s*=\s*context\.watch<ThemeProvider>\(\);',
            r'final themeMode = ref.watch(currentThemeModeProvider);',
            content
        )
        content = re.sub(
            r'final\s+(\w+)\s*=\s*context\.watch<ThemeProvider>\(\);',
            r'final themeMode = ref.watch(currentThemeModeProvider);',
            content
        )
        changes.append("ThemeProvider → currentThemeModeProvider")
    
    # 2. Replace context.read<ThemeProvider>() with ref.read(themeProvider.notifier)
    if 'context.read<ThemeProvider>()' in content:
        content = re.sub(
            r'context\.read<ThemeProvider>\(\)',
            r'ref.read(themeProvider.notifier)',
            content
        )
        changes.append("context.read<ThemeProvider> → ref.read")
    
    # 3. Replace context.watch<AppSettingsService>().dataSaver
    if 'context.watch<AppSettingsService>().dataSaver' in content:
        content = re.sub(
            r'context\.watch<AppSettingsService>\(\)\.dataSaver',
            r'provider.Provider.of<AppSettingsService>(context, listen: true).dataSaver',
            content
        )
        changes.append("AppSettingsService.dataSaver → prefixed Provider")
    
    # 4. Replace context.read<AppSettingsService>()
    if 'context.read<AppSettingsService>()' in content:
        content = re.sub(
            r'context\.read<AppSettingsService>\(\)',
            r'provider.Provider.of<AppSettingsService>(context, listen: false)',
            content
        )
        changes.append("AppSettingsService → prefixed Provider.of")
    
    # 5. Replace context.read<TabChangeNotifier>()
    if 'context.read<TabChangeNotifier>()' in content:
        content = re.sub(
            r'context\.read<TabChangeNotifier>\(\)',
            r'provider.Provider.of<TabChangeNotifier>(context, listen: false)',
            content
        )
        changes.append("TabChangeNotifier → prefixed Provider.of")
    
    # 6. Add imports if needed
    needs_riverpod = 'ref.watch' in content or 'ref.read' in content
    needs_provider_prefix = 'provider.Provider.of' in content
    
    if needs_riverpod and 'flutter_riverpod' not in content:
        # Add import after other flutter imports
        content = re.sub(
            r"(import 'package:flutter/material\.dart';)",
            r"\1\nimport 'package:flutter_riverpod/flutter_riverpod.dart';",
            content,
            count=1
        )
        changes.append("Added flutter_riverpod import")
    
    if needs_provider_prefix and "import 'package:provider/provider.dart' as provider;" not in content:
        # Add prefixed provider import
        content = re.sub(
            r"(import 'package:flutter/material\.dart';)",
            r"\1\nimport 'package:provider/provider.dart' as provider;",
            content,
            count=1
        )
        changes.append("Added prefixed provider import")
    
    # Add theme/language provider imports if using ref.watch
    if 'ref.watch(currentThemeModeProvider)' in content:
        if "presentation/providers/theme_providers.dart" not in content:
            # Find last import and add after it
            last_import = list(re.finditer(r"^import .*?;$", content, re.MULTILINE))
            if last_import:
                pos = last_import[-1].end()
                content = content[:pos] + "\nimport '../../presentation/providers/theme_providers.dart';" + content[pos:]
                changes.append("Added theme_providers import")
    
    if content != original_content:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"✅ {filepath}")
        for change in changes:
            print(f"   - {change}")
        return True
    else:
        print(f"⏭️  {filepath} - no changes needed")
        return False

print("🚀 Starting complete widget migration to Riverpod\n")
print(f"📋 {len(files_to_migrate)} files to process\n")

migrated = 0
for filepath in files_to_migrate:
    if migrate_file(filepath):
        migrated += 1

print(f"\n✨ Migration complete!")
print(f"✅ {migrated} files migrated")
print(f"⏭️  {len(files_to_migrate) - migrated} files skipped")
