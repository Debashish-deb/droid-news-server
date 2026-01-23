#!/usr/bin/env python3
"""Fix the specific syntax error in quiz widget line 366"""

filepath = "lib/features/quiz/daily_quiz_widget.dart"

with open(filepath, 'r') as f:
    lines = f.readlines()

# Fix line 366 (index 365)
if len(lines) > 365:
    old_line = lines[365]
    # Replace the broken syntax
    new_line = "                    child: Text(AppLocalizations.of(context)!.next.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),\n"
    lines[365] = new_line
    print(f"Old: {old_line.strip()}")
    print(f"New: {new_line.strip()}")
    
    with open(filepath, 'w') as f:
        f.writelines(lines)
    print("✅ Fixed!")
else:
    print("❌ File too short")
