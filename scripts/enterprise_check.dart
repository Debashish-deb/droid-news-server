// scripts/enterprise_check.dart

import 'dart:io';

/// Automated check for Enterprise Standards in the 'droid' codebase.
void main() async {
  print('🚀 Starting Enterprise Standards Check...');

  bool allPassed = true;

  // 1. Check for absolute imports
  print('\n🔍 Checking for relative imports in lib/ (Standard: package:)');
  final libDir = Directory('lib');
  final relativeImports = _findRelativeImports(libDir);
  if (relativeImports.isNotEmpty) {
    print('❌ FAILED: Found relative imports in:');
    relativeImports.forEach(print);
    allPassed = false;
  } else {
    print('✅ PASSED: All imports use package: prefix');
  }

  // 2. Check for unused security TODOs
  print('\n🔍 Checking for critical TODOs in security files');
  final securityFiles = _findSecurityFiles(libDir);
  final securityTodos = _findTodos(securityFiles);
  if (securityTodos.isNotEmpty) {
    print('⚠️ WARNING: Critical TODOs found in security layer:');
    securityTodos.forEach(print);
  } else {
    print('✅ PASSED: No critical TODOs in security layer');
  }

  // 3. Verify DI Registration for Enterprise Services
  print('\n🔍 Verifying DI Container for Part 4 services');
  final diFile = File('lib/bootstrap/di/injection_container.dart');
  final diContent = await diFile.readAsString();
  final services = [
    'DeviceTrustService',
    'SessionManager',
    'EntitlementService',
    'IntegrityService',
    'FeatureFlagService',
    'ComplianceService'
  ];
  
  for (final service in services) {
    if (!diContent.contains(service)) {
      print('❌ FAILED: Service $service not registered in DI container');
      allPassed = false;
    }
  }

  if (allPassed) {
    print('\n✨ ALL ENTERPRISE CHECKS PASSED ✨');
    exit(0);
  } else {
    print('\n❌ ENTERPRISE CHECKS FAILED');
    exit(1);
  }
}

List<String> _findRelativeImports(Directory dir) {
  final results = <String>[];
  dir.listSync(recursive: true).forEach((entity) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final lines = entity.readAsLinesSync();
      for (var line in lines) {
        if (line.trim().startsWith('import \'../') || line.trim().startsWith('import \'./')) {
          results.add('${entity.path}: $line');
        }
      }
    }
  });
  return results;
}

List<File> _findSecurityFiles(Directory dir) {
  return dir.listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.contains('security') || f.path.contains('identity'))
      .toList();
}

List<String> _findTodos(List<File> files) {
  final results = <String>[];
  for (var file in files) {
    final lines = file.readAsLinesSync();
    for (var line in lines) {
      if (line.contains('TODO') || line.contains('FIXME')) {
        results.add('${file.path}: $line');
      }
    }
  }
  return results;
}
