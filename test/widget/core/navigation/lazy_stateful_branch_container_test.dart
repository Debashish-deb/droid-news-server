import 'package:bdnewsreader/core/navigation/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mounts only the active branch until others are visited', (
    tester,
  ) async {
    final builds = <int, int>{0: 0, 1: 0, 2: 0};

    Widget branch(int index) => _BuildCounter(
      onInit: () => builds[index] = (builds[index] ?? 0) + 1,
      child: Text('branch-$index', textDirection: TextDirection.ltr),
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox.shrink(),
      ),
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LazyStatefulBranchContainer(
          currentIndex: 0,
          children: [branch(0), branch(1), branch(2)],
        ),
      ),
    );

    expect(builds[0], 1);
    expect(builds[1], 0);
    expect(builds[2], 0);
    expect(find.text('branch-0'), findsOneWidget);
    expect(find.text('branch-1'), findsNothing);
    expect(find.text('branch-2'), findsNothing);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LazyStatefulBranchContainer(
          currentIndex: 2,
          children: [branch(0), branch(1), branch(2)],
        ),
      ),
    );

    expect(builds[0], 1);
    expect(builds[1], 0);
    expect(builds[2], 1);
    expect(find.text('branch-2'), findsOneWidget);
  });
}

class _BuildCounter extends StatefulWidget {
  const _BuildCounter({required this.onInit, required this.child});

  final VoidCallback onInit;
  final Widget child;

  @override
  State<_BuildCounter> createState() => _BuildCounterState();
}

class _BuildCounterState extends State<_BuildCounter> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
