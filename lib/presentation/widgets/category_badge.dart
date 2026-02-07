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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final String name = categoryInfo!['name'] as String;
    final String colorHex = categoryInfo!['color'] as String;
    final Color baseColor = _parseColor(colorHex);

    final Color bgColor = isDark
        ? baseColor.withOpacity(0.22)
        : baseColor.withOpacity(0.14);

    final Color borderColor = baseColor.withOpacity(0.35);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size == CategoryBadgeSize.large ? 14 : 10,
        vertical: size == CategoryBadgeSize.large ? 7 : 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(
          size == CategoryBadgeSize.large ? 999 : 8,
        ),
        border: Border.all(color: borderColor),
        boxShadow: size == CategoryBadgeSize.large
            ? [
                BoxShadow(
                  color: baseColor.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (size == CategoryBadgeSize.large) ...[
            Icon(
              _getCategoryIcon(categoryInfo!['icon'] as String),
              size: 14,
              color: baseColor,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            name.toUpperCase(),
            style: TextStyle(
              fontSize: size == CategoryBadgeSize.large ? 11.5 : 10.5,
              fontWeight: FontWeight.w700,
              color: baseColor,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPERS ---

  Color _parseColor(String hex) {
    try {
      final value = hex.replaceFirst('#', '');
      return Color(int.parse(value, radix: 16) + 0xFF000000);
    } catch (_) {
      return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'sports_soccer':
        return Icons.sports_soccer_rounded;
      case 'computer':
        return Icons.computer_rounded;
      case 'business_center':
        return Icons.business_center_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'local_hospital':
        return Icons.local_hospital_rounded;
      case 'science':
        return Icons.science_rounded;
      case 'public':
        return Icons.public_rounded;
      default:
        return Icons.label_rounded;
    }
  }
}

enum CategoryBadgeSize {
  small,
  large,
}
