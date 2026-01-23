#!/usr/bin/env python3
"""
Fix StatefulWidget migrations - they need ConsumerStatefulWidget pattern
"""

import re

STATEFUL_FILES = {
    "lib/features/quiz/daily_quiz_widget.dart": "_DailyQuizWidgetState",
    "lib/features/profile/profile_screen.dart": "_ProfileScreenState",
    "lib/features/history/history_widget.dart": "_HistoryWidgetState",
    "lib/features/common/animated_background.dart": "_AnimatedBackgroundState",
    "lib/features/news_detail/animated_background.dart": "_AnimatedBackgroundState",
    "lib/features/news/newspaper_screen.dart": "_NewspaperScreenState",
    "lib/features/magazine/magazine_screen.dart": "_MagazineScreenState",
    "lib/features/magazine/widgets/magazine_card.dart": "_MagazineCardState",
    "lib/features/news_detail/news_detail_screen.dart": "_NewsDetailScreenState",
}

def fix_stateful_file(filepath, state_class):
    with open(filepath, 'r') as f:
        content = f.read()
    
    original = content
    
    # 1. Change build signature back for StatefulWidget State classes
    # Pattern: class _XState extends State<X> { ... Widget build(BuildContext context, WidgetRef ref)
    # Fix: Widget build(BuildContext context)
    content = re.sub(
        rf'(class {state_class}.*?Widget build\()BuildContext context, WidgetRef ref\)',
        r'\1BuildContext context)',
        content,
        flags=re.DOTALL
    )
    
    # 2. Remove the leftover themeProv line that script didn't catch
    content = re.sub(
        r'^\s*final themeProv = provider\.Provider\.of<ThemeProvider>\(context\);.*$',
        '',
        content,
        flags=re.MULTILINE
    )
    
    # 3. Add themeMode variable at start of build method
    # Find the build method and add themeMode ref after it
    build_pattern = rf'(Widget build\(BuildContext context\) \{{)\s*\n(\s*)(final AppLocalizations)'
    
    replacement = r'\1\n\2// Get theme from widget (parent should pass WidgetRef)\n\2final themeMode = AppThemeMode.system; // TODO: Get from context\n\2\3'
    content = re.sub(build_pattern, replacement, content)
    
    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        return True
    return False

if __name__ == "__main__":
    import os
    base_dir = "/Users/debashishdeb/Documents/JS/MobileApp/droid"
    
    for file, state_class in STATEFUL_FILES.items():
        filepath = os.path.join(base_dir, file)
        if os.path.exists(filepath):
            if fix_stateful_file(filepath, state_class):
                print(f"✅ Fixed: {file}")
            else:
                print(f"⏭️  No changes: {file}")
