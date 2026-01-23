import 'dart:io';
import 'package:flutter/foundation.dart';

/// Result of root/jailbreak detection
class RootStatus {
  final bool isRooted;
  final double confidence;
  final int indicators;
  final List<String> detectedIndicators;
  
  const RootStatus({
    required this.isRooted,
    required this.confidence,
    required this.indicators,
    required this.detectedIndicators,
  });
  
  @override
  String toString() => 'RootStatus(rooted: $isRooted, confidence: ${(confidence * 100).toStringAsFixed(1)}%, indicators: $indicators)';
}

/// Multi-layered Root/Jailbreak Detector
/// 
/// Uses multiple detection methods to reduce false positives:
/// - SU binary path checking
/// - Suspicious package detection
/// - Build tag verification
/// - Test key detection
/// - Debuggable property checking
class RootDetector {
  // Known SU binary locations
  static const List<String> _suspiciousPaths = [
    '/system/bin/su',
    '/system/xbin/su',
    '/sbin/su',
    '/system/su',
    '/system/bin/.ext/.su',
    '/system/usr/we-need-root/su',
    '/system/app/Superuser.apk',
    '/data/local/xbin/su',
    '/data/local/bin/su',
    '/system/sd/xbin/su',
    '/system/bin/failsafe/su',
    '/data/local/su',
  ];
  
  // Known rooting apps
  static const List<String> _suspiciousPackages = [
    'com.topjohnwu.magisk',
    'com.koushikdutta.superuser',
    'eu.chainfire.supersu',
    'com.noshufou.android.su',
    'com.thirdparty.superuser',
    'com.yellowes.su',
    'com.koushikdutta.rommanager',
    'com.dimonvideo.luckypatcher',
    'com.chelpus.lackypatch',
    'com.ramdroid.appquarantine',
  ];
  
  /// Perform multi-layered root detection
  /// 
  /// Returns [RootStatus] with confidence score
  /// Requires 2+ indicators to consider device rooted (reduces false positives)
  static Future<RootStatus> detect() async {
    final detectedIndicators = <String>[];
    final checks = <Future<bool>>[
      _checkSuPaths().then((result) {
        if (result) detectedIndicators.add('SU Binary Found');
        return result;
      }),
      _checkSuspiciousPackages().then((result) {
        if (result) detectedIndicators.add('Root App Installed');
        return result;
      }),
      _checkBuildTags().then((result) {
        if (result) detectedIndicators.add('Test Keys in Build');
        return result;
      }),
      _checkTestKeys().then((result) {
        if (result) detectedIndicators.add('Engineering Build');
        return result;
      }),
      _checkDangerousProps().then((result) {
        if (result) detectedIndicators.add('Debuggable System');
        return result;
      }),
    ];
    
    final results = await Future.wait(checks);
    final indicators = results.where((check) => check).length;
    final confidence = indicators / results.length;
    
    // Require 2+ indicators to reduce false positives
    final isRooted = indicators >= 2;
    
    if (isRooted) {
      debugPrint('🚨 ROOT DETECTED: $indicators/${results.length} indicators');
      debugPrint('   Detected: ${detectedIndicators.join(", ")}');
    }
    
    return RootStatus(
      isRooted: isRooted,
      confidence: confidence,
      indicators: indicators,
      detectedIndicators: detectedIndicators,
    );
  }
  
  /// Check for SU binary in known locations
  static Future<bool> _checkSuPaths() async {
    if (!Platform.isAndroid) return false;
    
    for (final path in _suspiciousPaths) {
      try {
        if (await File(path).exists()) {
          debugPrint('⚠️ Found SU binary: $path');
          return true;
        }
      } catch (e) {
        // Permission denied is expected on non-rooted devices
        continue;
      }
    }
    return false;
  }
  
  /// Check for known rooting apps
  static Future<bool> _checkSuspiciousPackages() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await Process.run('pm', ['list', 'packages']);
      final packages = result.stdout.toString();
      
      for (final suspiciousPackage in _suspiciousPackages) {
        if (packages.contains(suspiciousPackage)) {
          debugPrint('⚠️ Found suspicious package: $suspiciousPackage');
          return true;
        }
      }
    } catch (e) {
      debugPrint('Failed to check packages: $e');
    }
    
    return false;
  }
  
  /// Check build tags for "test-keys"
  static Future<bool> _checkBuildTags() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await Process.run('getprop', ['ro.build.tags']);
      final tags = result.stdout.toString().trim();
      
      if (tags.contains('test-keys')) {
        debugPrint('⚠️ Build contains test-keys: $tags');
        return true;
      }
    } catch (e) {
      debugPrint('Failed to check build tags: $e');
    }
    
    return false;
  }
  
  /// Check for engineering/userdebug builds
  static Future<bool> _checkTestKeys() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await Process.run('getprop', ['ro.build.type']);
      final buildType = result.stdout.toString().trim();
      
      if (buildType == 'eng' || buildType == 'userdebug') {
        debugPrint('⚠️ Engineering build detected: $buildType');
        return true;
      }
    } catch (e) {
      debugPrint('Failed to check build type: $e');
    }
    
    return false;
  }
  
  /// Check if system is debuggable
  static Future<bool> _checkDangerousProps() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await Process.run('getprop', ['ro.debuggable']);
      final isDebuggable = result.stdout.toString().trim() == '1';
      
      if (isDebuggable) {
        debugPrint('⚠️ System is debuggable');
      }
      
      return isDebuggable;
    } catch (e) {
      debugPrint('Failed to check debuggable prop: $e');
    }
    
    return false;
  }
}
