#!/bin/bash
# Security Dependency Audit Script
# Run this regularly to check for vulnerabilities

echo "🔍 Security Dependency Audit - BD News Reader"
echo "=============================================="
echo ""

# 1. Flutter dependency audit
echo "📦 Checking Flutter dependencies..."
flutter pub outdated
echo ""

# 2. Check for known vulnerabilities (requires pub_audit)
echo "🔐 Checking for known security vulnerabilities..."
if command -v dart &> /dev/null; then
    dart pub global activate pub_audit 2>/dev/null || true
    dart pub global run pub_audit || echo "⚠️ Install pub_audit: dart pub global activate pub_audit"
fi
echo ""

# 3. Android dependency check (requires gradle)
echo "🤖 Checking Android dependencies..."
cd android
./gradlew dependencyUpdates || echo "⚠️ dependencyUpdates plugin not installed"
cd ..
echo ""

# 4. Check for outdated packages with security issues
echo "📋 Outdated packages report:"
flutter pub outdated --mode=null-safety
echo ""

# 5. License compliance check
echo "📜 License compliance:"
flutter pub licenses --show-sdk | head -50
echo ""

# 6. Summary
echo "✅ Audit complete!"
echo ""
echo "📝 Next steps:"
echo "1. Review 'flutter pub outdated' for security updates"
echo "2. Update packages: flutter pub upgrade"
echo "3. Test after upgrades: flutter test"
echo "4. Check changelog for breaking changes"
echo ""
echo "🔄 Run this script monthly or before major releases"
