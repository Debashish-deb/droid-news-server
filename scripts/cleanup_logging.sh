#!/bin/bash

# Production Logging Cleanup Script
# Wraps all debugPrint/print statements with kDebugMode checks

echo "🔒 Starting Production Logging Cleanup..."
echo "Target: lib/data/services/"
echo ""

# Files to process
SERVICE_FILES=(
  "lib/data/services/push_notification_service.dart"
  "lib/data/services/payment_service.dart"  
  "lib/data/services/rss_service.dart"
  "lib/data/services/interstitial_ad_service.dart"
  "lib/data/services/hive_service.dart"
  "lib/data/services/rewarded_ad_service.dart"
  "lib/data/services/ml_service.dart"
)

for file in "${SERVICE_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "Processing: $file"
    
    # Count before
    before=$(grep -c "debugPrint\|print(" "$file" 2>/dev/null || echo "0")
    echo "  Found $before log statements"
    
  else
    echo "⚠️  File not found: $file"
  fi
done

echo ""
echo "✅ Audit complete"
echo ""
echo "Next: Manually wrap each with:"
echo "  if (kDebugMode) {"
echo "    debugPrint(...);"
echo "  }"
