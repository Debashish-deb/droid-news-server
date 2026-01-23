import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Service to handle Machine Learning operations using TensorFlow Lite
class MLService {
  factory MLService() => _instance;
  MLService._internal();
  // Singleton instance
  static final MLService _instance = MLService._internal();

  Interpreter? _interpreter;

  // Isolate engine
  Isolate? _inferenceIsolate;
  SendPort? _isolateSendPort;
  ReceivePort? _isolateReceivePort;

  final Map<int, Completer<void>> _pending = <int, Completer<void>>{};
  int _reqId = 0;

  bool _isLoading = false;
  bool _isClosed = false;

  bool get isModelLoaded => _interpreter != null;

  /// Load a TensorFlow Lite model from assets
  Future<void> loadModel(String assetPath) async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      if (_interpreter != null) {
        close();
      }

      final options = InterpreterOptions();

      // Optional CPU acceleration
      try {
        options.addDelegate(XNNPackDelegate());
      } catch (_) {}

      _interpreter = await Interpreter.fromAsset(assetPath, options: options);
      _isClosed = false;

      if (kDebugMode) {
        debugPrint('🧠 ML Model loaded successfully: $assetPath');
        final inputShape = _interpreter!.getInputTensor(0).shape;
        final outputShape = _interpreter!.getOutputTensor(0).shape;
        debugPrint('🧠 Input Shape: $inputShape');
        debugPrint('🧠 Output Shape: $outputShape');
      }

      // Warm-up main thread interpreter (keeps old behavior fast)
      _warmUpMain();

      // Start isolate engine (platform-grade)
      await _startInferenceIsolate(assetPath);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('❌ Error loading ML model: $e');
        debugPrint(st.toString());
      }
      throw Exception('Failed to load model: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// Run inference on the loaded model (MAIN THREAD, synchronous)
  /// [input] - The input data (e.g., List of floats, TypedData)
  /// [output] - Pre-allocated buffer for the output
  void predict(Object input, Object output) {
    if (_interpreter == null || _isClosed) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    try {
      _interpreter!.run(input, output);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('❌ Inference error: $e');
        debugPrint(st.toString());
      }
      rethrow;
    }
  }

  /// Run inference in ISOLATE (async, non-blocking UI)
  ///
  /// Keeps your output-buffer pattern (fills [output]).
  /// NOTE: [input] and [output] must be isolate-sendable.
  Future<void> predictInIsolate(Object input, Object output) async {
    if (_isClosed) {
      throw StateError('MLService is closed.');
    }
    if (_isolateSendPort == null) {
      // If isolate failed to start, fall back to main thread predict.
      predict(input, output);
      return;
    }

    final id = _nextReqId();
    final completer = Completer<void>();
    _pending[id] = completer;

    try {
      _isolateSendPort!.send({
        'type': 'run',
        'id': id,
        'input': input,
        'output': output,
      });

      await completer.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      _pending.remove(id);
      // Fallback to main thread if isolate is stuck (platform-grade resilience)
      if (kDebugMode) debugPrint('⚠️ Isolate inference timeout. Falling back.');
      predict(input, output);
    }
  }

  /// Close the interpreter and release resources
  void close() {
    if (_isClosed) return;
    _isClosed = true;

    // Stop isolate engine
    _stopInferenceIsolate();

    // Close main interpreter
    try {
      _interpreter?.close();
    } catch (_) {
      // ignore
    } finally {
      _interpreter = null;
    }
  }

  // ---------------------------------------------------------------------------
  // INTERNAL — ISOLATE ENGINE
  // ---------------------------------------------------------------------------

  int _nextReqId() {
    _reqId = (_reqId + 1) & 0x7fffffff;
    return _reqId == 0 ? (_reqId = 1) : _reqId;
  }

  Future<void> _startInferenceIsolate(String assetPath) async {
    // Clean previous isolate if any
    _stopInferenceIsolate();

    // Web doesn’t support isolates the same way for this use case
    if (kIsWeb) return;

    final token = RootIsolateToken.instance;
    if (token == null) return;

    _isolateReceivePort = ReceivePort();

    // Spawn isolate
    _inferenceIsolate = await Isolate.spawn<_IsolateBootArgs>(
      _inferenceIsolateEntry,
      _IsolateBootArgs(
        rootToken: token,
        mainSendPort: _isolateReceivePort!.sendPort,
        assetPath: assetPath,
      ),
      debugName: 'ml_inference_isolate',
    );

    // Handshake: wait for isolate SendPort
    final sendPort =
        await _isolateReceivePort!.firstWhere((m) => m is SendPort) as SendPort;

    _isolateSendPort = sendPort;

    // Listen for responses (keep port open)
    _isolateReceivePort!.listen((message) {
      if (message is Map) {
        final type = message['type'];
        if (type == 'ok') {
          final id = message['id'] as int?;
          if (id != null) {
            _pending.remove(id)?.complete();
          }
        } else if (type == 'err') {
          final id = message['id'] as int?;
          final err = message['error']?.toString() ?? 'Unknown isolate error';
          if (id != null) {
            _pending.remove(id)?.completeError(Exception(err));
          }
          if (kDebugMode) debugPrint('❌ Isolate inference error: $err');
        } else if (type == 'log') {
          if (kDebugMode) debugPrint(message['msg']?.toString() ?? '');
        }
      }
    });

    if (kDebugMode) debugPrint('✅ ML inference isolate started');
  }

  void _stopInferenceIsolate() {
    // Fail any pending requests
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.completeError(StateError('Inference isolate stopped.'));
      }
    }
    _pending.clear();

    _isolateSendPort = null;

    try {
      _isolateReceivePort?.close();
    } catch (_) {}
    _isolateReceivePort = null;

    try {
      _inferenceIsolate?.kill(priority: Isolate.immediate);
    } catch (_) {}
    _inferenceIsolate = null;
  }

  void _warmUpMain() {
    if (_interpreter == null) return;
    try {
      final inT = _interpreter!.getInputTensor(0);
      final outT = _interpreter!.getOutputTensor(0);

      final dummyIn = _zeroFloatBuffer(inT.shape);
      final dummyOut = _zeroFloatBuffer(outT.shape);

      _interpreter!.run(dummyIn, dummyOut);

      if (kDebugMode) debugPrint('🔥 Main interpreter warm-up done');
    } catch (_) {}
  }

  Object _zeroFloatBuffer(List<int> shape) {
    int total = 1;
    for (final d in shape) {
      total *= math.max(1, d);
    }
    return List<double>.filled(total, 0.0);
  }
}

class _IsolateBootArgs {
  const _IsolateBootArgs({
    required this.rootToken,
    required this.mainSendPort,
    required this.assetPath,
  });

  final RootIsolateToken rootToken;
  final SendPort mainSendPort;
  final String assetPath;
}

Future<void> _inferenceIsolateEntry(_IsolateBootArgs args) async {
  // Required for using assets/platform channels inside isolate
  BackgroundIsolateBinaryMessenger.ensureInitialized(args.rootToken);

  final ReceivePort isolatePort = ReceivePort();
  args.mainSendPort.send(isolatePort.sendPort);

  Interpreter? interpreter;

  try {
    final options = InterpreterOptions();
    try {
      options.addDelegate(XNNPackDelegate());
    } catch (_) {}

    interpreter = await Interpreter.fromAsset(args.assetPath, options: options);

    args.mainSendPort.send({
      'type': 'log',
      'msg': '🧠 Isolate model loaded: ${args.assetPath}',
    });
  } catch (e) {
    args.mainSendPort.send({
      'type': 'log',
      'msg': '❌ Isolate failed to load model: $e',
    });
    // If we can’t load, keep the isolate alive but it will error on runs.
  }

  isolatePort.listen((dynamic message) async {
    if (message is! Map) return;

    final type = message['type'];
    if (type == 'run') {
      final id = message['id'] as int? ?? -1;
      final input = message['input'];
      final output = message['output'];

      if (interpreter == null) {
        args.mainSendPort.send({
          'type': 'err',
          'id': id,
          'error': 'Model not loaded in isolate.',
        });
        return;
      }

      try {
        interpreter!.run(input, output);

        args.mainSendPort.send({'type': 'ok', 'id': id});
      } catch (e) {
        args.mainSendPort.send({
          'type': 'err',
          'id': id,
          'error': e.toString(),
        });
      }
    } else if (type == 'close') {
      try {
        interpreter?.close();
      } catch (_) {}
      interpreter = null;

      isolatePort.close();
    }
  });
}
