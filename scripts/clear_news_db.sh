#!/bin/bash

# Clear the local database to force re-fetching news from RSS
echo "🗑️  Clearing app database to fetch fresh news..."

# Find the app's data directory - different for iOS/Android
# For Android emulator:
adb shell run-as com.example.bdnewsreader rm -rf /data/data/com.example.bdnewsreader/databases/news.db 2>/dev/null

# For iOS simulator (if applicable):
# xcrun simctl get_app_container booted com.example.bdnewsreader data 2>/dev/null | xargs -I {} rm -rf {}/Library/Application\ Support/news.db

echo "✅  Database cleared. App will fetch fresh news from RSS feeds on next launch."
echo ""
echo "📰 To test:"
echo "1. Run: flutter run"
echo "2. Wait for the app to load - it will fetch real news from RSS feeds"
echo "3. Check that home screen shows real news instead of 'Global Tech Summit'"
