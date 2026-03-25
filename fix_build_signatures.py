#!/usr/bin/env python3
"""Fix build method signatures - remove WidgetRef ref from State classes"""
import re

FILES_TO_FIX = [
    "lib/features/splash/splash_screen.dart",
    "lib/features/profile/login_screen.dart",
    "lib/features/profile/signup_screen.dart",
    "lib/features/news/newspaper_screen.dart",
    "lib/features/magazine/magazine_screen.dart",
    "lib/features/extras/extras_screen.dart",
    "lib/features/favorites/favorites_screen.dart",
    "lib/features/about/about_screen.dart",
    "lib/features/search/search_screen.dart",
    "lib/features/news_detail/news_detail_screen.dart",
    "lib/features/common/webview_screen.dart",
]

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    original = content
    
    # Remove WidgetRef ref from build methods (keep only BuildContext)
    content = re.sub(
        r'Widget build\(BuildContext context, WidgetRef ref\)',
        r'Widget build(BuildContext context)',
        content
    )
    
    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"✅ Fixed {filepath}")
        return True
    else:
        print(f"⏭️  No changes for {filepath}")
        return False

def main():
    print("🔧 Fixing build method signatures...")
    count = 0
    for filepath in FILES_TO_FIX:
        if fix_file(filepath):
            count += 1
    print(f"\n✨ Fixed {count}/{len(FILES_TO_FIX)} files")

if __name__ == "__main__":
    main()
