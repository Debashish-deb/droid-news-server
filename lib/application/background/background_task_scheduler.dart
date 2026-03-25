/// Priority level for background tasks
enum TaskPriority {
  low,
  medium,
  high,
}

/// Network requirements for the task
enum NetworkType {
  any,
  connected,
  unmetered,
  none,
}

/// Abstract base class for all background tasks
abstract class BackgroundTask {
  String get id;
  TaskPriority get priority;
  NetworkType get networkRequirements;
  
  /// Execute the task. Returns true if successful.
  Future<bool> execute();
  
  /// Serialize task metadata for persistence (if needed)
  Map<String, dynamic> toMap();
}

/// Singleton scheduler to manage background tasks
class BackgroundTaskScheduler {
  factory BackgroundTaskScheduler() => _instance;
  BackgroundTaskScheduler._();
  static final BackgroundTaskScheduler _instance = BackgroundTaskScheduler._();

  final List<BackgroundTask> _queue = [];
  bool _isProcessing = false;

  /// Add a task to the queue
  void schedule(BackgroundTask task) {
    final int index = _queue.indexWhere((t) => t.priority.index < task.priority.index);
    if (index == -1) {
      _queue.add(task);
    } else {
      _queue.insert(index, task);
    }
    
    _processQueue();
  }

  /// Process the queue
  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;
    
    while (_queue.isNotEmpty) {
      final task = _queue.first;
      
      
      try {
        final success = await task.execute();
        if (success) {
          _queue.removeAt(0);
        } else {
          _queue.removeAt(0);
        }
      } catch (e) {
         _queue.removeAt(0);
      }
    }
    
    _isProcessing = false;
  }
}
