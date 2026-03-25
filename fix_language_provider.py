#!/usr/bin/env python3
"""Fix Settings screen to use new Riverpod language provider"""
import re

file = "lib/features/settings/settings_screen.dart"

with open(file, 'r') as f:
    content = f.read()

# Replace legacy LanguageProvider.of() with Riverpod ref.read(languageProvider.notifier)
content = re.sub(
    r'context\.read<LanguageProvider>\(\)',
    r'ref.read(languageProvider.notifier)',
    content
)

# Also replace any direct context.watch<LanguageProvider>
content = re.sub(
    r'context\.watch<LanguageProvider>\(\)',
    r'ref.watch(languageProvider)',
    content
)

with open(file, 'w') as f:
    f.write(content)

print("✅ Fixed LanguageProvider → Riverpod languageProvider")
