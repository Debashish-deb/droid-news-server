#!/usr/bin/env python3
"""
Bulk convert remaining StatefulWidgets to ConsumerStatefulWidget
"""

import re
import os

BASE = "/Users/debashishdeb/Documents/JS/MobileApp/droid"

# Map of file -> (widget_class, state_class)
CONVERSIONS = {
    "lib/features/profile/profile_screen.dart": ("ProfileScreen", "_ProfileScreenState"),
    "lib/features/history/history_widget.dart": ("HistoryWidget", "_HistoryWidgetState"),
    "lib/features/common/animated_background.dart": ("AnimatedBackground", "_AnimatedBackgroundState"),
    "lib/features/news_detail/animated_background.dart": ("AnimatedBackground", "_AnimatedBackgroundState"),
    "lib/features/news/newspaper_screen.dart": ("NewspaperScreen", "_NewspaperScreenState"),
    "lib/features/magazine/magazine_screen.dart": ("MagazineScreen", "_MagazineScreenState"),
    "lib/features/magazine/widgets/magazine_card.dart": ("MagazineCard", "_MagazineCardState"),
    "lib/features/news_detail/news_detail_screen.dart": ("NewsDetailScreen", "_NewsDetailScreenState"),
}

def convert_stateful(filepath, widget, state):
    with open(filepath, 'r') as f:
        content = f.read()
    
    orig = content
    
    # 1. Convert widget class
    content = re.sub(
        rf'class {widget} extends StatefulWidget',
        f'class {widget} extends ConsumerStatefulWidget',
        content
    )
    
    # 2. Convert createState return type
    content = re.sub(
        rf'State<{widget}> createState\(\)',
        f'ConsumerState<{widget}> createState()',
        content
    )
    
    # 3. Convert state class
    content = re.sub(
        rf'class {state} extends State<{widget}>',
        f'class {state} extends ConsumerState<{widget}>',
        content
    )
    
    # 4. Fix build signature (remove WidgetRef ref if present)
    content = re.sub(
        r'Widget build\(BuildContext context, WidgetRef ref\)',
        r'Widget build(BuildContext context)',
        content
    )
    
    # 5. Remove leftover themeProv declarations
    content = re.sub(
        r'^\s*final\s+(themeProv|prov)\s*=\s*provider\.Provider\.of<ThemeProvider>\(context\);.*$',
        '',
        content,
        flags=re.MULTILINE
    )
    
    # 6. Add themeMode at start of build (if build method exists)
    # Find build method and inject themeMode
    build_match = re.search(r'(@override\s+)?Widget build\(BuildContext context\)\s*\{', content)
    if build_match:
        insert_pos = build_match.end()
        # Check if themeMode already exists
        if 'final AppThemeMode themeMode = ref.watch(currentThemeModeProvider)' not in content:
            injection = '\n    final AppThemeMode themeMode = ref.watch(currentThemeModeProvider);'
            content = content[:insert_pos] + injection + content[insert_pos:]
    
    if content != orig:
        with open(filepath, 'w') as f:
            f.write(content)
        return True
    return False

if __name__ == "__main__":
    for file, (widget, state) in CONVERSIONS.items():
        path = os.path.join(BASE, file)
        if os.path.exists(path):
            if convert_stateful(path, widget, state):
                print(f"✅ {file}")
            else:
                print(f"⏭️  {file} (no changes)")
        else:
            print(f"❌ {file} not found")
