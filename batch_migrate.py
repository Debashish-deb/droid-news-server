#!/usr/bin/env python3
"""
Batch migration script for converting Provider to Riverpod
Usage: python3 batch_migrate.py
"""

import re
import os
from pathlib import Path

# Screens to migrate with their provider usage
SCREENS = {
    "lib/features/profile/login_screen.dart": ["theme"],
    "lib/features/profile/signup_screen.dart": ["theme"],  
    "lib/features/news/newspaper_screen.dart": ["theme", "tab", "favorites"],
    "lib/features/magazine/magazine_screen.dart": ["theme", "tab", "favorites"],
    "lib/features/favorites/favorites_screen.dart": ["theme", "favorites"],
    "lib/features/search/search_screen.dart": ["theme"],
    "lib/features/extras/extras_screen.dart": ["theme"],
    "lib/features/about/about_screen.dart": ["theme"],
    "lib/features/common/webview_screen.dart": ["theme"],
    "lib/features/news_detail/news_detail_screen.dart": ["theme"],
    "lib/features/splash/splash_screen.dart": ["theme"],
}

def migrate_file(filepath, providers):
    """Migrate a single file"""
    print(f"📝 Migrating {filepath}...")
    
    with open(filepath, 'r') as f:
        content = f.read()
    
    # 1. Add import prefix for provider package
    content = content.replace(
        "import 'package:provider/provider.dart';",
        "import 'package:provider/provider.dart' as provider;\nimport 'package:flutter_riverpod/flutter_riverpod.dart';"
    )
    
    # 2. Add Riverpod provider imports
    import_section = ""
    if "theme" in providers:
        import_section += "import '../../presentation/providers/theme_providers.dart';\n"
    if "premium" in providers:
        import_section += "import '../../presentation/providers/subscription_providers.dart';\n"
    if "language" in providers:
        import_section += "import '../../presentation/providers/language_providers.dart';\n"
    
    # Insert after existing imports
    if import_section:
        # Find last import line
        import_pattern = r"(import '[^']+';)"
        matches = list(re.finditer(import_pattern, content))
        if matches:
            last_import = matches[-1]
            pos = last_import.end()
            content = content[:pos] + "\n" + import_section + content[pos:]
    
    # 3. Convert widget types
    content = re.sub(
        r'class (\w+Screen) extends StatefulWidget',
        r'class \1 extends ConsumerStatefulWidget',
        content
    )
    content = re.sub(
        r'State<(\w+Screen)> createState\(\)',
        r'ConsumerState<\1> createState()',
        content
    )
    content = re.sub(
        r'class _(\w+ScreenState) extends State<(\w+Screen)>',
        r'class _\1 extends ConsumerState<\2>',
        content
    )
    
    # 4. Convert StatelessWidget
    content = re.sub(
        r'class (\w+Screen) extends StatelessWidget',
        r'class \1 extends ConsumerWidget',
        content
    )
    content = re.sub(
        r'Widget build\(BuildContext context\) {',
        r'Widget build(BuildContext context, WidgetRef ref) {',
        content
    )
    
    # Write back
    with open(filepath, 'w') as f:
        f.write(content)
    
    print(f"✅ Completed {filepath}")

def main():
    print("🚀 Starting batch migration...")
    
    for filepath, providers in SCREENS.items():
        if os.path.exists(filepath):
            migrate_file(filepath, providers)
        else:
            print(f"⚠️  Skipping {filepath} (not found)")
    
    print("\n✨ Migration complete!")
    print("⚠️  Manual steps remaining:")
    print("  1. Replace context.watch/read with ref.watch/read")
    print("  2. Update provider references") 
    print("  3. Testcompile")

if __name__ == "__main__":
    main()
