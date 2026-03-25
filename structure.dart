import 'dart:io';

void main() async {
  final libDir = Directory('lib');
  final outputFile = File('project_structure.txt');

  if (!libDir.existsSync()) {
    stderr.writeln('❌ lib directory not found');
    exit(1);
  }

  final buffer = StringBuffer();
  buffer.writeln('lib/');

  await writeDirectory(
    dir: libDir,
    buffer: buffer,
    prefix: '',
  );

  await outputFile.writeAsString(buffer.toString());

  print('✅ Project structure written to project_structure.txt');
}

Future<void> writeDirectory({
  required Directory dir,
  required StringBuffer buffer,
  required String prefix,
}) async {
  final entities = dir
      .listSync()
      ..sort((a, b) => a.path.compareTo(b.path));

  for (int i = 0; i < entities.length; i++) {
    final entity = entities[i];
    final isLast = i == entities.length - 1;
    final name = entity.uri.pathSegments.last;

    final branch = isLast ? '└── ' : '├── ';
    buffer.writeln('$prefix$branch$name');

    if (entity is Directory) {
      final nextPrefix = prefix + (isLast ? '    ' : '│   ');
      await writeDirectory(
        dir: entity,
        buffer: buffer,
        prefix: nextPrefix,
      );
    }
  }
}
