#!/usr/bin/env python3
"""Fix all compilation errors from the automated migration"""
import os
import re

# Map of files and their fixes
fixes = {
    # 1. Fix import path (lib/features/presentation → lib/presentation)
    "lib/features/home/widgets/news_card.dart": {
        "wrong_import": "../../presentation/providers/app_settings_providers.dart",
        "correct_import": "../../../presentation/providers/app_settings_providers.dart",
        "needs_stateful_fix": True,
    },
    
    # 2. Fix StatefulWidget build signatures (remove WidgetRef ref param)
    "lib/features/news/widgets/news_card.dart": {
        "needs_stateful_fix": True,
    },
    "lib/features/magazine/widgets/magazine_card.dart": {
        "needs_stateful_fix": True,
    },
    "lib/features/quiz/daily_quiz_widget.dart": {
        "needs_stateful_fix": True,
    },
    "lib/features/news_detail/animated_background.dart": {
        "needs_stateful_fix": True,
    },
    
    # 3. Files with undefined 'prov' - need to get ThemeProvider via Provider.of
    "lib/features/news/newspaper_screen.dart": {
        "needs_prov_fix": True,
    },
    "lib/features/magazine/magazine_screen.dart": {
        "needs_prov_fix": True,
    },
    "lib/features/news_detail/news_detail_screen.dart": {
        "needs_prov_fix": True,
    },
    "lib/features/home/widgets/professional_header.dart": {
        "needs_consumer_widget": True,  # This one IS ConsumerWidget, just needs prov fix
    },
}

def fix_import_path(content, wrong, correct):
    """Fix incorrect import path"""
    return content.replace(wrong, correct)

def fix_stateful_build_signature(content):
    """Remove WidgetRef ref parameter from StatefulWidget build methods"""
    # Pattern: Widget build(BuildContext context, WidgetRef ref)
    # Replace: Widget build(BuildContext context)
    content = re.sub(
        r'Widget build\(BuildContext context, WidgetRef ref\)',
        r'Widget build(BuildContext context)',
        content
    )
    
    # Also remove any ref.watch calls by getting theme via Provider
    # Replace: ref.watch(...) with Provider.of<...>
    if 'ref.watch(currentThemeModeProvider)' in content:
        # Add necessary import if not present
        if 'package:provider/provider.dart' not in content:
            # Find last import
            last_import_match = list(re.finditer(r'^import .*?;$', content, re.MULTILINE))
            if last_import_match:
                pos = last_import_match[-1].end()
                content = content[:pos] + "\nimport 'package:provider/provider.dart';" + content[pos:]
        
        # Replace ref.watch with Provider.of
        content = re.sub(
            r'final themeMode = ref\.watch\(currentThemeModeProvider\);',
            "final themeProv = Provider.of<ThemeProvider>(context);",
            content
        )
        
        # Replace prov.appThemeMode with themeProv.appThemeMode
        content = content.replace('prov.appThemeMode', 'themeProv.appThemeMode')
        content = content.replace('prov.', 'themeProv.')
    
    return content

def fix_prov_undefined(content):
    """Add ThemeProvider prov variable where it's undefined"""
    # Check if build method exists and doesn't have prov defined
    if 'Widget build(BuildContext context)' in content and 'final prov' not in content:
        # Add prov definition after theme variables
        content = re.sub(
            r'(final themeMode = ref\.watch\(currentThemeModeProvider\);)',
            r'\1\n    final prov = Provider.of<ThemeProvider>(context);',
            content
        )
    
    return content

def fix_provider_ambiguity(content):
    """Fix Provider class ambiguity by using provider prefix"""
    # If both packages are imported
    if 'package:provider/provider.dart' in content and 'package:riverpod' in content:
        # Use provider.Provider for legacy one
        content = re.sub(
            r'(\s+)Provider\.of<ThemeProvider>',
            r'\1provider.Provider.of<ThemeProvider>',
            content
        )
        
        # Make sure provider package is prefixed
        if "import 'package:provider/provider.dart';" in content:
            content = content.replace(
                "import 'package:provider/provider.dart';",
                "import 'package:provider/provider.dart' as provider;"
            )
    
    return content

print("🔧 Fixing compilation errors...\n")

fixed_count = 0

for filepath, fix_config in fixes.items():
    if not os.path.exists(filepath):
        print(f"⚠️  {filepath} - not found")
        continue
    
    with open(filepath, 'r') as f:
        content = f.read()
    
    original = content
    
    # Apply fixes based on configuration
    if 'wrong_import' in fix_config:
        content = fix_import_path(content, fix_config['wrong_import'], fix_config['correct_import'])
        print(f"✅ {filepath} - fixed import path")
    
    if fix_config.get('needs_stateful_fix'):
        content = fix_stateful_build_signature(content)
        print(f"✅ {filepath} - fixed build signature")
    
    if fix_config.get('needs_prov_fix'):
        content = fix_prov_undefined(content)
        print(f"✅ {filepath} - added prov variable")
    
    # Always check for Provider ambiguity
    content = fix_provider_ambiguity(content)
    
    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        fixed_count += 1

print(f"\n✨ Fixed {fixed_count} files")
print("\n⚡ Running additional manual fixes...")
