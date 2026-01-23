import 'package:flutter/material.dart';

/// Simple activity chart for weekly reading stats
class ActivityChart extends StatelessWidget {
  const ActivityChart({
    required this.data,
    required this.labels,
    super.key,
    this.height = 120,
    this.barColor = Colors.blue,
  });

  final List<double> data; // Values 0-1 representing activity level
  final List<String> labels; // Day labels
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
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Bar
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
                                colors: [barColor.withOpacity(0.8), barColor],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Label
                  Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.7),
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
