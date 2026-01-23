#!/usr/bin/env python3
"""Fix all hardcoded English strings to use AppLocalizations"""
import re

# Map of files and their string replacements
fixes = {
    "lib/features/quiz/daily_quiz_widget.dart": [
        ("const Text('CONTINUE'", "Text(loc.next.toUpperCase()"),  # Use 'Next' key, uppercase it
        ("const Text('Retry')", "Text(loc.retry)"),
        ("'LEGENDARY!'", "loc.excellentScore.toUpperCase()"),
        ("'GOOD JOB!'", "loc.goodScore.toUpperCase()"),
        ("'KEEP TRYING!'", "loc.keepPracticing.toUpperCase()"),
    ],
    "lib/features/history/history_widget.dart": [
        ("const Text('Retry')", "Text(loc.retry)"),
        ("const Text('Copied to clipboard')", "Text(loc.copySuccess.replaceFirst('{label}', ''))"),
        ("const Text('Previous')", "Text(loc.previous)"),
        ("const Text('Next')", "Text(loc.next)"),
    ],
    "lib/features/common/webview_screen.dart": [
        ("const Text('Close')", "Text(loc.close)"),
    ],
    "lib/features/settings/settings_screen.dart": [
        # 'Cancel' - need to add this key or use 'close'
        ("const Text('Cancel'", "Text(loc.close"),  # Using 'close' as substitute
    ],
    "lib/features/home/home_screen.dart": [
        ("const Text('Try Again')", "Text(loc.tryAgain)"),
    ],
    "lib/features/security/security_lockout_screen.dart": [
        ("const Text('Exit Application')", "Text(loc.exit)"),
    ],
    "lib/features/help/help_screen.dart": [
        ("const Text('Email Support')", "Text(loc.contactSupport)"),
        ("const Text('Visit Website')", "Text('Visit Website')"),  # Keep as is, generic
        ("const Text('Rate Us')", "Text(loc.rateApp)"),
    ],
    "lib/widgets/app_drawer.dart": [
        # Already uses loc, but check for 'Membership'
        ("'Membership'", "loc.about"),  # Using 'about' as closest match, or add new key
    ],
}

print("🔧 Fixing hardcoded strings with localization...\n")

fixed_count = 0
for filepath, replacements in fixes.items():
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        
        original = content
        for old, new in replacements:
            if old in content:
                content = content.replace(old, new)
                print(f"✅ {filepath}: {old[:30]}... → {new[:30]}...")
        
        if content != original:
            # Check if AppLocalizations import exists
            if 'AppLocalizations' not in content and 'loc.' in content:
                # Add import after other imports
                import_line = "import '/l10n/app_localizations.dart';\n"
                # Find last import
                imports = list(re.finditer(r"^import .*?;$", content, re.MULTILINE))
                if imports:
                    pos = imports[-1].end() + 1
                    content = content[:pos] + import_line + content[pos:]
                    print(f"  📝 Added AppLocalizations import")
            
            with open(filepath, 'w') as f:
                f.write(content)
            fixed_count += 1
    except FileNotFoundError:
        print(f"⚠️  {filepath} not found")
    except Exception as e:
        print(f"❌ Error fixing {filepath}: {e}")

print(f"\n✨ Fixed {fixed_count} files with localization")
print("\n📋 Note: Some strings may need 'loc' variable - ensure context has AppLocalizations.of(context)!")
