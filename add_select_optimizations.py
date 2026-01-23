#!/usr/bin/env python3
"""
Phase B: Add .select() optimizations to prevent unnecessary rebuilds

Strategy:
1. Find all ref.watch(provider) calls
2. Identify which properties are actually used
3. Add .select() to watch only those properties
"""

import re
import os

# High-priority files for optimization
optimizations = {
    "lib/features/settings/settings_screen.dart": {
        "currentThemeModeProvider": ["isDarkMode", "glassColor"],
        "isPremiumProvider": None,  # Already primitive, optimal
        "currentLocaleProvider": None,  # Already primitive, optimal
    },
    "lib/features/home/home_screen.dart": {
        "currentThemeModeProvider": ["isDarkMode"],
        "isPremiumProvider": None,
    },
    "lib/features/news/widgets/news_card.dart": {
        "currentThemeModeProvider": ["isDarkMode", "glassColor"],
    },
    "lib/features/magazine/widgets/magazine_card.dart": {
        "currentThemeModeProvider": ["isDarkMode", "glassColor"],
    },
}

def add_select_optimization(filepath, provider, property_name):
    """Add .select() to a specific ref.watch call"""
    
    if not os.path.exists(filepath):
        return False
    
    with open(filepath, 'r') as f:
        content = f.read()
    
    original = content
    
    # Pattern: ref.watch(providerName)
    # Replace with: ref.watch(providerName.select((state) => state.property))
    
    # For theme provider, we need to be more specific
    if provider == "currentThemeModeProvider" and property_name:
        # This is actually AppThemeMode enum, not a state object
        # We can't select properties from an enum
        # Skip this - it's already optimal
        return False
    
    # For StateNotifierProvider, add select
    pattern = f"ref\\.watch\\({provider}\\)"
    
    if property_name:
        replacement = f"ref.watch({provider}.select((state) => state.{property_name}))"
        content = re.sub(pattern, replacement, content)
    
    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        return True
    
    return False

print("🎯 Phase B: Adding .select() optimizations")
print("=" * 50)

optimized_count = 0

for filepath, providers in optimizations.items():
    print(f"\n📁 {filepath}")
    
    for provider, properties in providers.items():
        if properties is None:
            print(f"  ✓ {provider} - already optimal (primitive type)")
            continue
        
        for prop in properties:
            if add_select_optimization(filepath, provider, prop):
                print(f"  ✅ Added .select() for {provider}.{prop}")
                optimized_count += 1
            else:
                print(f"  ⏭️  {provider}.{prop} - no optimization needed")

print(f"\n{'=' * 50}")
print(f"✨ Optimization complete!")
print(f"📊 {optimized_count} .select() optimizations added")
print(f"\n💡 Note: Some providers are already optimal (primitives like bool, String)")
print(f"   These don't need .select() as they already rebuild minimally")
