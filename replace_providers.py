#!/usr/bin/env python3
"""Replace Provider calls with Riverpod in migrated files"""
import re

SCREENS = [
    "lib/features/profile/login_screen.dart",
    "lib/features/profile/signup_screen.dart",
    "lib/features/news/newspaper_screen.dart",
    "lib/features/magazine/magazine_screen.dart",
    "lib/features/favorites/favorites_screen.dart",
    "lib/features/search/search_screen.dart",
    "lib/features/extras/extras_screen.dart",
    "lib/features/about/about_screen.dart",
    "lib/features/common/webview_screen.dart",
    "lib/features/news_detail/news_detail_screen.dart",
    "lib/features/splash/splash_screen.dart",
]

def replace_providers(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    original = content
    
    # Replace context.watch<ThemeProvider>().appThemeMode -> ref.watch(currentThemeModeProvider)
    content = re.sub(
        r'context\.watch<ThemeProvider>\(\)\.appThemeMode',
        r'ref.watch(currentThemeModeProvider)',
        content
    )
    
    # Replace context.watch<ThemeProvider>().isDarkMode -> ref.watch(isDarkModeProvider)
    content = re.sub(
        r'context\.watch<ThemeProvider>\(\)\.isDarkMode',
        r'ref.watch(isDarkModeProvider)',
        content
    )
    
    # Replace context.watch<ThemeProvider>() -> keep for now, need borderColor etc
    # We'll handle these case by case
    
    # Replace context.read<TabChangeNotifier>() -> provider.Provider.of<TabChangeNotifier>(context, listen: false)
    content = re.sub(
        r'context\.read<TabChangeNotifier>\(\)',
        r'provider.Provider.of<TabChangeNotifier>(context, listen: false)',
        content
    )
    
    # Replace context.watch<FavoritesManager>() -> provider.Provider.of<FavoritesManager>(context)
    content = re.sub(
        r'context\.watch<FavoritesManager>\(\)',
        r'provider.Provider.of<FavoritesManager>(context)',
        content
    )
    
    # Replace context.read<FavoritesManager>() -> provider.Provider.of<FavoritesManager>(context, listen: false)
    content = re.sub(
        r'context\.read<FavoritesManager>\(\)',
        r'provider.Provider.of<FavoritesManager>(context, listen: false)',
        content
    )
    
    # Replace context.watch<PremiumService>().isPremium -> ref.watch(isPremiumProvider)
    content = re.sub(
        r'context\.watch<PremiumService>\(\)\.isPremium',
        r'ref.watch(isPremiumProvider)',
        content
    )
    
    # Replace context.read<PremiumService>().isPremium -> ref.watch(isPremiumProvider)  
    content = re.sub(
        r'context\.read<PremiumService>\(\)\.isPremium',
        r'ref.watch(isPremiumProvider)',
        content
    )
    
    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"✅ Updated {filepath}")
        return True
    else:
        print(f"⏭️  No changes for {filepath}")
        return False

def main():
    print("🔄 Replacing Provider calls with Riverpod...")
    count = 0
    for filepath in SCREENS:
        if replace_providers(filepath):
            count += 1
    print(f"\n✨ Updated {count}/{len(SCREENS)} files")

if __name__ == "__main__":
    main()
