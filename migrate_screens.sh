#!/bin/bash
# Batch migration script for converting Provider to Riverpod in screen files

# List of files to migrate (excluding settings_screen.dart which is already done)
FILES=(
  "lib/features/home/home_screen.dart"
  "lib/features/profile/profile_screen.dart"
  "lib/features/profile/login_screen.dart"
  "lib/features/profile/signup_screen.dart"
  "lib/features/news/newspaper_screen.dart"
  "lib/features/news_detail/news_detail_screen.dart"
  "lib/features/magazine/magazine_screen.dart"
  "lib/features/favorites/favorites_screen.dart"
  "lib/features/search/search_screen.dart"
  "lib/features/extras/extras_screen.dart"
  "lib/features/about/about_screen.dart"
  "lib/features/common/webview_screen.dart"
  "lib/features/splash/splash_screen.dart"
)

echo "🔄 Starting batch migration of ${#FILES[@]} files..."

for file in "${FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo "⚠️  Skipping $file (not found)"
    continue
  fi
  
  echo "📝 Processing: $file"
  
  # Create backup
  cp "$file" "${file}.bak"
  
  # 1. Add Riverpod import if Provider is used
  if grep -q "import 'package:provider/provider.dart'" "$file"; then
    sed -i '' "s|import 'package:provider/provider.dart';|import 'package:provider/provider.dart' as provider;\nimport 'package:flutter_riverpod/flutter_riverpod.dart';|" "$file"
  fi
  
  # 2. Add Riverpod provider imports if theme/language/premium are used
  if grep -q "ThemeProvider\|LanguageProvider\|PremiumService" "$file"; then
    # Add imports after existing imports (before first non-import line)
    awk '
      /^import/ { print; imports=1; next }
      imports && !/^import/ && !added {
        if (/ThemeProvider/)
          print "import '\''../../presentation/providers/theme_providers.dart'\'';"
        if (/LanguageProvider/)
          print "import '\''../../presentation/providers/language_providers.dart'\'';"  
        if (/PremiumService/)
          print "import '\''../../presentation/providers/subscription_providers.dart'\'';"
        added=1
      }
      { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
  fi
  
  echo "✅ Completed: $file"
done

echo "🎉 Batch processing complete!"
echo "📋 Manual steps remaining:"
echo "  1. Convert StatefulWidget -> Consumer StatefulWidget"
echo "  2. Replace context.watch/read with ref.watch/read"
echo "  3. Test each screen"
