import 'package:flutter/material.dart';

/// Category badge widget for displaying article categories
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    required this.categoryId,
    this.categoryInfo,
    this.size = CategoryBadgeSize.small,
    super.key,
  });

  final String categoryId;
  final Map<String, dynamic>? categoryInfo;
  final CategoryBadgeSize size;

  @override
  Widget build(BuildContext context) {
    if (categoryInfo == null) return const SizedBox.shrink();

    final name = categoryInfo!['name'] as String;
    final colorHex = categoryInfo!['color'] as String;
    final color = _parseColor(colorHex);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size == CategoryBadgeSize.large ? 12 : 8,
        vertical: size == CategoryBadgeSize.large ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(
          size == CategoryBadgeSize.large ? 8 : 6,
        ),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (size == CategoryBadgeSize.large) ...[
            Icon(
              _getCategoryIcon(categoryInfo!['icon'] as String),
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            name.toUpperCase(),
            style: TextStyle(
              fontSize: size == CategoryBadgeSize.large ? 11 : 10,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
    } catch (_) {
      return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'account_balance':
        return Icons.account_balance;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'computer':
        return Icons.computer;
      case 'business_center':
        return Icons.business_center;
      case 'movie':
        return Icons.movie;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'science':
        return Icons.science;
      case 'public':
        return Icons.public;
      default:
        return Icons.label;
    }
  }
}

enum CategoryBadgeSize { small, large }
