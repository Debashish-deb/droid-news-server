import 'dart:io';

Future<void> main() async {
  final String scriptPath = Platform.script.toFilePath();
  final File scriptFile = File(scriptPath);
  final Directory scriptDir = scriptFile.parent;

  final File outputFile = File('${scriptDir.path}/combined_dart_code.dart');
  print('🔍 Scanning: ${scriptDir.path}');

  // Collect all .dart files (excluding this script)
  final List<File> dartFiles = await _collectDartFiles(scriptDir, scriptFile);

  // Combine into one file
  await _combineFiles(dartFiles, outputFile);

  print(
    '✅ Success! Combined ${dartFiles.length} Dart files into:\n   ${outputFile.path}',
  );
}

Future<List<File>> _collectDartFiles(Directory dir, File excludeFile) async {
  final List<File> dartFiles = <File>[];

  await for (final FileSystemEntity entity in dir.list(recursive: true)) {
    if (entity is File &&
        entity.path.endsWith('.dart') &&
        !_isSameFile(entity, excludeFile)) {
      // Skip the excluded file
      dartFiles.add(entity);
    }
  }

  return dartFiles;
}

Future<void> _combineFiles(List<File> files, File output) async {
  final IOSink sink = output.openWrite();

  for (final File file in files) {
    sink.writeln('// === ${file.path} ===\n');
    sink.write(await file.readAsString());
    sink.writeln('\n');
  }

  await sink.close();
}

bool _isSameFile(File file1, File file2) {
  // Compare canonical paths to handle symlinks
  return File(file1.path).absolute.path == File(file2.path).absolute.path;
}
