import 'package:flutter/material.dart';
import '../../core/theme/theme_skeleton.dart';

class ActivityChart extends StatelessWidget {
  const ActivityChart({
    required this.data,
    required this.labels,
    super.key,
    this.height = 120,
    this.barColor = Colors.blue,
  });

  final List<double> data;
  final List<String> labels;
  final double height;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(data.length, (index) {
          return Expanded(
            child: Padding(
              padding: ThemeSkeleton.shared.insetsSymmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 800 + (index * 100)),
                      curve: Curves.easeOutCubic,
                      tween: Tween(begin: 0.0, end: data[index]),
                      builder: (context, value, child) {
                        return FractionallySizedBox(
                          heightFactor: value,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  barColor.withValues(alpha: 0.8),
                                  barColor,
                                ],
                              ),
                              borderRadius: BorderRadius.vertical(
                                top: ThemeSkeleton.shared.radius(4),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: ThemeSkeleton.size8),

                  Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
