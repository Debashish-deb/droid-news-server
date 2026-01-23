#!/bin/bash
# Performance Baseline Measurement Script
# Run this to establish performance metrics before optimization

echo "🎯 BD News Reader - Performance Baseline Measurement"
echo "===================================================="
echo ""

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

# Clean build
echo "🧹 Cleaning previous builds..."
flutter clean
flutter pub get

# Build release APK for size measurement
echo ""
echo "📦 Building release APK (this may take a few minutes)..."
flutter build apk --release

# Measure APK size
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
    echo "✅ APK Size: $APK_SIZE"
else
    echo "⚠️ APK not found at $APK_PATH"
fi

# Analyze build
echo ""
echo "📊 Analyzing APK..."
flutter build apk --release --analyze-size 2>&1 | tail -30

# Count linting issues
echo ""
echo "🔍 Analyzing code quality..."
LINT_COUNT=$(flutter analyze lib/ 2>&1 | grep -c "^  error •" || echo "0")
INFO_COUNT=$(flutter analyze lib/ 2>&1 | grep -c "^  info •" || echo "0")
echo "Errors: $LINT_COUNT"
echo "Info/Warnings: $INFO_COUNT"

# Dependency count
echo ""
echo "📚 Dependency analysis..."
DIRECT_DEPS=$(grep "^  [a-z]" pubspec.yaml | wc -l | tr -d ' ')
echo "Direct dependencies: $DIRECT_DEPS"

# Test coverage
echo ""
echo "🧪 Running tests..."
flutter test --coverage 2>&1 | tail -10

if [ -f "coverage/lcov.info" ]; then
    # Install lcov if not present
    if command -v lcov &> /dev/null; then
        COVERAGE=$(lcov --summary coverage/lcov.info 2>&1 | grep "lines" | grep -oE '[0-9]+\.[0-9]+%' | head -1)
        echo "✅ Test Coverage: $COVERAGE"
    else
        echo "ℹ️ Install lcov for coverage percentage: brew install lcov"
    fi
fi

# Summary
echo ""
echo "📋 Baseline Summary"
echo "===================="
echo "APK Size: ${APK_SIZE:-Unknown}"
echo "Lint Errors: $LINT_COUNT"
echo "Lint Warnings: $INFO_COUNT"
echo "Dependencies: $DIRECT_DEPS"
echo "Test Coverage: ${COVERAGE:-Unknown}"
echo ""
echo "✅ Baseline measurement complete!"
echo "Save these metrics for comparison after optimization."
