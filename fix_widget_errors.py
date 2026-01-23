#!/usr/bin/env python3
"""Fix compilation errors: Convert to ConsumerWidget and fix variable references"""
import os
import re

# Files with errors that need widget conversion
files_to_fix = {
    "lib/features/common/animated_background.dart": "StatelessWidget",
    "lib/features/history/history_widget.dart": "StatelessWidget",
    "lib/features/news/widgets/news_card.dart": "StatelessWidget",
    "lib/features/magazine/widgets/magazine_card.dart": "StatelessWidget",
    "lib/features/quiz/daily_quiz_widget.dart": "StatelessWidget",
    "lib/features/news_detail/animated_background.dart": "StatelessWidget",
    "lib/features/extras/extras_screen.dart": "ConsumerStatefulWidget",
    "lib/features/magazine/magazine_screen.dart": "ConsumerStatefulWidget",
    "lib/features/news/newspaper_screen.dart": "ConsumerStatefulWidget",
    "lib/features/news_detail/news_detail_screen.dart": "ConsumerStatefulWidget",
    "lib/features/home/widgets/professional_header.dart": "StatelessWidget",
}

def fix_stateless_widget(filepath):
    """Convert StatelessWidget to ConsumerWidget"""
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Convert extends StatelessWidget to ConsumerWidget
    content = re.sub(
        r'extends StatelessWidget',
        r'extends ConsumerWidget',
        content
    )
    
    # Fix build method signature
    content = re.sub(
        r'Widget build\(BuildContext context\)',
        r'Widget build(BuildContext context, WidgetRef ref)',
        content
    )
    
    return content

def fix_stateful_widget(filepath):
    """Ensure ConsumerStatefulWidget is used"""
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Already should be ConsumerStatefulWidget, just need to ensure State has ref
    # Check if State<> extends ConsumerState
    if 'extends State<' in content and 'extends ConsumerState<' not in content:
        content = re.sub(
            r'extends State<(\w+)>',
            r'extends ConsumerState<\1>',
            content
        )
    
    return content

def fix_variable_references(content):
    """Fix old variable names like 'prov' to 'themeMode'"""
    
    # Replace prov.isDark / prov.isLight with themeMode checks
    content = re.sub(
        r'prov\.isDark',
        r'(themeMode == AppThemeMode.dark || themeMode == AppThemeMode.amoled || themeMode == AppThemeMode.bangladesh)',
        content
    )
    
    content = re.sub(
        r'prov\.isLight',
        r'(themeMode == AppThemeMode.light)',
        content
    )
    
    content = re.sub(
        r'prov\.isBangladesh',
        r'(themeMode == AppThemeMode.bangladesh)',
        content
    )
    
    # Replace theme.isDark with themeMode checks (for animated_background.dart)
    content = re.sub(
        r'theme\.isDark',
        r'(themeMode == AppThemeMode.dark || themeMode == AppThemeMode.amoled || themeMode == AppThemeMode.bangladesh)',
        content
    )
    
    return content

def fix_import_path(content, filepath):
    """Fix import paths based on file location"""
    # Calculate correct relative path to presentation/providers
    parts = filepath.split('/')
    features_idx = parts.index('features')
    depth = len(parts) - features_idx - 2  # -2 for features and filename
    
    prefix = '../' * (depth + 1)
    correct_path = f"{prefix}presentation/providers/theme_providers.dart"
    
    # Replace incorrect import path
    content = re.sub(
        r"import '\.\.\/\.\.\/presentation\/providers\/theme_providers\.dart';",
        f"import '{correct_path}';",
        content
    )
    
    return content

print("🔧 Fixing compilation errors in migrated widgets\n")

for filepath, widget_type in files_to_fix.items():
    if not os.path.exists(filepath):
        print(f"⚠️  Skipping {filepath} - not found")
        continue
    
    print(f"Fixing {filepath}...")
    
    with open(filepath, 'r') as f:
        content = f.read()
    
    original = content
    
    # Fix widget type
    if widget_type == "StatelessWidget":
        content = fix_stateless_widget(filepath)
    elif widget_type == "ConsumerStatefulWidget":
        content = fix_stateful_widget(filepath)
    
    # Fix variable references
    content = fix_variable_references(content)
    
    # Fix import paths
    content = fix_import_path(content, filepath)
    
    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"  ✅ Fixed")
    else:
        print(f"  ⏭️  No changes needed")

print("\n✨ Compilation error fixes complete!")
