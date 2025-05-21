#!/usr/bin/env dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;

class Config {
  final String listPath;
  final String outputDir;
  final Duration timeout;
  final String userAgent;
  final int maxRetries;
  final int concurrency;
  final int maxBytes;
  final int minWidth;
  final int minHeight;

  Config._({
    required this.listPath,
    required this.outputDir,
    required this.timeout,
    required this.userAgent,
    required this.maxRetries,
    required this.concurrency,
    required this.maxBytes,
    required this.minWidth,
    required this.minHeight,
  });

  factory Config.fromArgs(List<String> args) {
    final parser = ArgParser()
      ..addOption('list', abbr: 'l', defaultsTo: 'newspaperlist.txt')
      ..addOption('out', abbr: 'o', defaultsTo: 'logos')
      ..addOption('timeout', abbr: 't', defaultsTo: '20')
      ..addOption('retries', abbr: 'r', defaultsTo: '3')
      ..addOption('concurrency', abbr: 'c', defaultsTo: '4')
      ..addOption('max-size', defaultsTo: '${1024 * 500}')
      ..addOption('min-width', defaultsTo: '100')
      ..addOption('min-height', defaultsTo: '50');

    final opts = parser.parse(args);
    final scriptDir = p.dirname(Platform.script.toFilePath());
    final listArg = opts['list']!;
    final listFile = p.isAbsolute(listArg) ? listArg : p.join(scriptDir, listArg);

    return Config._(
      listPath: p.absolute(listFile),
      outputDir: p.absolute(opts['out']!),
      timeout: Duration(seconds: int.parse(opts['timeout']!)),
      userAgent: 'LogoCollector/1.0',
      maxRetries: int.parse(opts['retries']!),
      concurrency: int.parse(opts['concurrency']!),
      maxBytes: int.parse(opts['max-size']!),
      minWidth: int.parse(opts['min-width']!),
      minHeight: int.parse(opts['min-height']!),
    );
  }
}

Future<void> main(List<String> args) async {
  final config = Config.fromArgs(args);
  stdout.writeln('🚀 Starting logo collector...');
  await Directory(config.outputDir).create(recursive: true);

  final names = await _loadNames(config.listPath);
  final dio = Dio(BaseOptions(
    connectTimeout: config.timeout,
    receiveTimeout: config.timeout,
    headers: {HttpHeaders.userAgentHeader: config.userAgent},
    responseType: ResponseType.bytes,
  ));

  final sem = StreamController<void>.broadcast();
  for (var i = 0; i < config.concurrency; i++) {
    sem.add(null);
  }

  final futures = <Future>[];
  for (final name in names) {
    await for (final _ in sem.stream.take(1)) {
      futures.add(
        _processName(name, config, dio).whenComplete(() => sem.add(null)),
      );
    }
  }

  await Future.wait(futures);
  await sem.close();

  stdout.writeln('✅ Completed. Logos saved to: ${config.outputDir}');
}

Future<List<String>> _loadNames(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    stderr.writeln('❌ List file not found: $path');
    exit(1);
  }
  final lines = await file.readAsLines();
  return lines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
}

Future<void> _processName(String name, Config c, Dio dio) async {
  stdout.writeln('🔍 Searching logo for: $name');
  final candidates = await _searchLogoUrls(name, dio);
  for (final url in candidates) {
    try {
      final bytes = await _downloadBytes(url, dio);
      if (bytes.length > c.maxBytes) throw 'Too large';

      final image = img.decodeImage(bytes);
      if (image == null) throw 'Decode failure';
      if (image.width < c.minWidth || image.height < c.minHeight) {
        throw 'Dimensions too small';
      }
      if (!_hasTransparency(image)) throw 'No transparency';

      final ext = _getExt(url);
      final safe = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      final outFile = p.join(c.outputDir, '$safe.$ext');
      final encoded = ext == 'png' ? img.encodePng(image) : img.encodeJpg(image);
      await File(outFile).writeAsBytes(Uint8List.fromList(encoded));

      stdout.writeln('💾 Saved: $outFile');
      return;
    } catch (e) {
      stderr.writeln('⚠️ $url failed: $e');
    }
  }
  stderr.writeln('❌ No valid logo found for: $name');
}

Future<List<String>> _searchLogoUrls(String name, Dio dio) async {
  final query = Uri.encodeQueryComponent('$name logo');
  final url = 'https://duckduckgo.com/i.js?q=$query&iax=images&ia=images';

  final response = await dio.get(url, options: Options(responseType: ResponseType.plain));
  try {
    final data = json.decode(response.data!) as Map<String, dynamic>;
    final results = (data['results'] as List)
        .map((e) => e['image'] as String)
        .toList();
    return results.take(5).toList();
  } catch (e) {
    stderr.writeln('❌ Failed to parse search results: $e');
    return [];
  }
}

Future<Uint8List> _downloadBytes(String url, Dio dio) async {
  final resp = await dio.get<Uint8List>(url);
  if (resp.statusCode != 200 || resp.data == null) {
    throw 'HTTP ${resp.statusCode}';
  }
  return resp.data!;
}

bool _hasTransparency(img.Image image) {
  final bytes = image.getBytes(order: img.ChannelOrder.rgba);
  for (int i = 3; i < bytes.length; i += 4) {
    if (bytes[i] < 255) return true;
  }
  return false;
}

String _getExt(String url) {
  final ext = p.extension(Uri.parse(url).path).toLowerCase();
  return ext.startsWith('.') ? ext.substring(1) : 'png';
}
