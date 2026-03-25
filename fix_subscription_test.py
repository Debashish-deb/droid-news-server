#!/usr/bin/env python3
"""Add validateAndRefreshSubscription stubs to all subscription tests"""

import re

file = "test/unit/domain/use_cases/subscription/check_subscription_status_use_case_test.dart"

with open(file, 'r') as f:
    content = f.read()

# Add stub before each getCurrentSubscription call (skip the one we just added)
content = re.sub(
    r'(test\(.*?async \{.*?// Arrange.*?)(when\(mockRepository\.getCurrentSubscription)',
    r'\1when(mockRepository.validateAndRefreshSubscription())\n          .thenAnswer((_) async => Right(Subscription(\n            id: \'test\', userId: \'test\', tier: SubscriptionTier.free,\n            status: SubscriptionStatus.active, startDate: DateTime.now())));\n      \2',
    content,
    flags=re.DOTALL
)

with open(file, 'w') as f:
    f.write(content)

print("✅ Added stubs for validateAndRefreshSubscription")
