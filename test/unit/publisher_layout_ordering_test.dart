import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/presentation/features/publisher_layout/publisher_layout_ordering.dart';

void main() {
  group('publisher layout ordering', () {
    test('orders filtered publishers using saved layout ids', () {
      final publishers = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'a', 'name': 'A'},
        <String, dynamic>{'id': 'b', 'name': 'B'},
        <String, dynamic>{'id': 'c', 'name': 'C'},
      ];

      final ordered = orderPublishersByLayout(publishers, <String>[
        'c',
        'a',
        'b',
      ]);

      expect(ordered.map((publisher) => publisher['id']).toList(), <String>[
        'c',
        'a',
        'b',
      ]);
    });

    test('falls back to source order when saved layout is incomplete', () {
      final publishers = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'a'},
        <String, dynamic>{'id': 'b'},
        <String, dynamic>{'id': 'c'},
      ];

      final ordered = orderPublishersByLayout(publishers, <String>['c', 'a']);

      expect(ordered.map((publisher) => publisher['id']).toList(), <String>[
        'a',
        'b',
        'c',
      ]);
    });
  });
}
