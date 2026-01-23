import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/device_session.dart';
import '../../data/services/device_session_service.dart';

/// Screen for managing active device sessions
class DeviceManagementScreen extends ConsumerStatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  ConsumerState<DeviceManagementScreen> createState() =>
      _DeviceManagementScreenState();
}

class _DeviceManagementScreenState
    extends ConsumerState<DeviceManagementScreen> {
  final DeviceSessionService _deviceSession = DeviceSessionService();
  List<DeviceSession> _devices = [];
  String? _currentDeviceId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final devices = await _deviceSession.getActiveDevices();
      final currentId = await _deviceSession.getCurrentDeviceId();

      setState(() {
        _devices = devices;
        _currentDeviceId = currentId;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _revokeDevice(String deviceId, String deviceName) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout Device?'),
            content: Text(
              'Are you sure you want to logout from "$deviceName"?\n\n'
              'You will need to login again on that device.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Logout'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await _deviceSession.revokeDevice(deviceId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device logged out successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload devices
      _loadDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to logout device: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _revokeAllOtherDevices() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout All Other Devices?'),
            content: Text(
              'This will logout all ${_devices.length - 1} other devices.\n\n'
              'You will remain logged in on this device only.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Logout All'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await _deviceSession.revokeAllOtherDevices();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All other devices logged out'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload devices
      _loadDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to logout devices: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatLastActive(DateTime lastActive) {
    final now = DateTime.now();
    final difference = now.difference(lastActive);

    if (difference.inMinutes < 5) {
      return 'Now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(lastActive);
    }
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.android;
      case 'ios':
        return Icons.phone_iphone;
      default:
        return Icons.devices;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Active Devices'), centerTitle: true),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Error loading devices'),
                    const SizedBox(height: 8),
                    Text(_error!, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadDevices,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadDevices,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _devices.length + 3 + (_devices.length > 1 ? 1 : 0), // header(2) + devices + button (if >1) + info(1)
                  itemBuilder: (context, index) {
                    // Header section (2 items)
                    if (index == 0) {
                      return Text(
                        'Active Devices (${_devices.length}/${DeviceSessionService.maxFreeAndroidDevices + DeviceSessionService.maxFreeIosDevices})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }
                    if (index == 1) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24, top: 8),
                        child: Text(
                          'Free: 1 Android + 1 iOS • Premium: 2 Android + 1 iOS',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      );
                    }

                    // Device list
                    final deviceIndex = index - 2;
                    if (deviceIndex < _devices.length) {
                      final device = _devices[deviceIndex];
                      final isCurrentDevice = device.deviceId == _currentDeviceId;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor:
                                isCurrentDevice
                                    ? colorScheme.primary
                                    : Colors.grey[300],
                            child: Icon(
                              _getPlatformIcon(device.platform),
                              color:
                                  isCurrentDevice
                                      ? Colors.white
                                      : Colors.grey[700],
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  device.deviceName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isCurrentDevice)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'This Device',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${device.platform.toUpperCase()} • v${device.appVersion}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Last active: ${_formatLastActive(device.lastActive)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          trailing:
                              !isCurrentDevice
                                  ? IconButton(
                                    icon: const Icon(Icons.logout, color: Colors.red),
                                    onPressed:
                                        () => _revokeDevice(
                                          device.deviceId,
                                          device.deviceName,
                                        ),
                                    tooltip: 'Logout',
                                  )
                                  : null,
                        ),
                      );
                    }

                    // Logout all button (if multiple devices)
                    if (_devices.length > 1 && deviceIndex == _devices.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 24),
                        child: OutlinedButton.icon(
                          onPressed: _revokeAllOtherDevices,
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text(
                            'Logout All Other Devices',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      );
                    }

                    // Info section (last item)
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Devices are automatically logged out after 30 days of inactivity.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
