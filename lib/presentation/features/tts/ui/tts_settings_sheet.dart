import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/feature_providers.dart';

class TtsSettingsSheet extends ConsumerStatefulWidget {
  const TtsSettingsSheet({super.key});

  @override
  ConsumerState<TtsSettingsSheet> createState() => _TtsSettingsSheetState();
}

class _TtsSettingsSheetState extends ConsumerState<TtsSettingsSheet> {
  double _speed = 1.0;
  double _pitch = 1.0;
  double _volume = 1.0;
  List<Map<String, String>> _voices = [];
  Map<String, String>? _selectedVoice;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final voices = await ref.read(ttsManagerProvider).getAvailableVoices();
    setState(() {
      _voices = voices;
      _selectedVoice = voices.firstWhere(
        (v) => v['locale']?.contains('bn') ?? false,
        orElse: () => voices.isNotEmpty ? voices.first : {},
      );
      if (_selectedVoice?.isEmpty ?? true) _selectedVoice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final manager = ref.read(ttsManagerProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Audio Settings',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_rounded),
                  onPressed: () => Navigator.pop(context),
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 24),
  
      
            _buildSettingRow(
              label: 'Speed',
              value: '${_speed.toStringAsFixed(1)}x',
              icon: Icons.speed_rounded,
              child: Slider(
                value: _speed,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                onChanged: (val) {
                  setState(() => _speed = val);
                  manager.setSpeed(val);
                },
              ),
            ),
  
  
            _buildSettingRow(
              label: 'Pitch',
              value: _pitch.toStringAsFixed(1),
              icon: Icons.graphic_eq_rounded,
              child: Slider(
                value: _pitch,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                onChanged: (val) {
                  setState(() => _pitch = val);
                  manager.setPitch(val);
                },
              ),
            ),
  
  
            _buildSettingRow(
              label: 'Volume',
              value: '${(_volume * 100).toInt()}%',
              icon: Icons.volume_up_rounded,
              child: Slider(
                value: _volume,
                onChanged: (val) {
                  setState(() => _volume = val);
                  manager.setVolume(val);
                },
              ),
            ),
  
            if (_voices.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Voice Selection',
                style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
              ),
              const SizedBox(height: 12),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: scheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _voices.length,
                  itemBuilder: (context, index) {
                    final voice = _voices[index];
                    final isSelected = _selectedVoice?['name'] == voice['name'];
                    return ListTile(
                      dense: true,
                      title: Text(voice['name'] ?? 'Unknown Voice'),
                      subtitle: Text(voice['locale'] ?? ''),
                      trailing: isSelected 
                        ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                        : null,
                      onTap: () {
                        setState(() => _selectedVoice = voice);
                        manager.setVoice(voice['name']!, voice['locale']!);
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required String label,
    required String value,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(value, style: theme.textTheme.bodySmall),
            ],
          ),
          child,
        ],
      ),
    );
  }
}
