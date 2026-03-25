// scripts/broken_import_fixer.dart

import 'dart:io';

void main() {
  final mappings = {
    'package:bdnewsreader/core/services/theme_providers.dart': 'package:bdnewsreader/presentation/providers/theme_providers.dart',
    'package:bdnewsreader/core/services/favorites_providers.dart': 'package:bdnewsreader/presentation/providers/favorites_providers.dart',
    'package:bdnewsreader/core/services/news_providers.dart': 'package:bdnewsreader/presentation/providers/news_providers.dart',
    'package:bdnewsreader/core/services/saved_articles_service.dart': 'package:bdnewsreader/infrastructure/persistence/saved_articles_service.dart',
    'package:bdnewsreader/core/services/offline_service.dart': 'package:bdnewsreader/infrastructure/persistence/offline_service.dart',
    'package:bdnewsreader/core/services/auth_service.dart': 'package:bdnewsreader/presentation/features/profile/auth_service.dart',
    'package:bdnewsreader/core/theme/tokens.dart': 'package:bdnewsreader/core/design_tokens.dart',
  };

  final searchDirs = [Directory('lib'), Directory('test')];
  
  for (final dir in searchDirs) {
    if (dir.existsSync()) {
      dir.listSync(recursive: true).forEach((entity) {
        if (entity is File && entity.path.endsWith('.dart')) {
          _fixBrokenImports(entity, mappings);
        }
      });
    }
  }
  print('✨ Broken import repair complete.');
}

void _fixBrokenImports(File file, Map<String, String> mappings) {
  final lines = file.readAsLinesSync();
  final newLines = <String>[];
  bool modified = false;

  for (var line in lines) {
    String newLine = line;
    mappings.forEach((oldPath, newPath) {
      if (line.contains(oldPath)) {
        newLine = newLine.replaceFirst(oldPath, newPath);
        modified = true;
      }
    });
    newLines.add(newLine);
  }

  if (modified) {
    file.writeAsStringSync(newLines.join('\n') + '\n');
    print('Repaired: ${file.path}');
  }
}
