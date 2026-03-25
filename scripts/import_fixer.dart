// scripts/import_fixer.dart

import 'dart:io';

void main() {
  final searchDirs = [Directory('lib'), Directory('test')];
  
  for (final dir in searchDirs) {
    if (dir.existsSync()) {
      dir.listSync(recursive: true).forEach((entity) {
        if (entity is File && entity.path.endsWith('.dart')) {
          _fixImportsInFile(entity);
          _cleanupDoubleSlashes(entity);
        }
      });
    }
  }
  print('✨ Import standardization complete.');
}

void _fixImportsInFile(File file) {
  final lines = file.readAsLinesSync();
  final newLines = <String>[];
  bool modified = false;

  for (var line in lines) {
    if (line.trim().startsWith('import \'')) {
      final match = RegExp(r"import '([^']+)").firstMatch(line);
      if (match != null) {
        final path = match.group(1)!;
        if (!path.startsWith('package:') && !path.startsWith('dart:') && !path.startsWith('plugin:')) {
          final absolutePkgPath = _resolveToPackagePath(file.path, path);
          newLines.add(line.replaceFirst(path, absolutePkgPath));
          modified = true;
          continue;
        }
      }
    }
    newLines.add(line);
  }

  if (modified) {
    file.writeAsStringSync('${newLines.join('\n')}\n');
    print('Fixed: ${file.path}');
  }
}

String _resolveToPackagePath(String filePath, String relativePath) {
  if (relativePath.startsWith('.')) {
    final segments = filePath.split(Platform.pathSeparator);
    // remove filename
    final dirSegments = segments.sublist(0, segments.length - 1);
    
    final relParts = relativePath.split('/');
    final resultSegments = [...dirSegments];
    
    for (final part in relParts) {
      if (part == '.') continue;
      if (part == '..') {
        if (resultSegments.isNotEmpty) resultSegments.removeLast();
      } else {
        resultSegments.add(part);
      }
    }
    
    // Ensure we start from after 'lib'
    final libIndex = resultSegments.indexOf('lib');
    if (libIndex != -1 && libIndex < resultSegments.length - 1) {
      return 'package:bdnewsreader/${resultSegments.sublist(libIndex + 1).join('/')}';
    }
    return 'package:bdnewsreader/${resultSegments.join('/')}';
  }
  return 'package:bdnewsreader/$relativePath';
}

void _cleanupDoubleSlashes(File file) {
  final content = file.readAsStringSync();
  if (content.contains('//')) {
    // Only target // after package:
    final newContent = content.replaceAll(RegExp(r'(package:bdnewsreader/?[^/]*?)//'), r'$1/');
    if (newContent != content) {
      file.writeAsStringSync(newContent);
    }
  }
}
