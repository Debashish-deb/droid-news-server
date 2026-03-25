import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/feature_providers.dart';

import '../services/tts_prosody_builder.dart';

const _kSpeed = 'tts_speed';
const _kPitch = 'tts_pitch';
const _kVolume = 'tts_volume';
const _kVoice = 'tts_voice_name';
const _kLocale = 'tts_voice_locale';

extension _TtsPresetUi on TtsPreset {
  String get label => switch (this) {
    TtsPreset.anchor => 'Anchor',
    TtsPreset.natural => 'Natural',
    TtsPreset.story => 'Story',
  };

  String get subtitle => switch (this) {
    TtsPreset.anchor => 'Steady, authoritative delivery',
    TtsPreset.natural => 'Balanced everyday reading',
    TtsPreset.story => 'Warm, expressive narration',
  };

  IconData get icon => switch (this) {
    TtsPreset.anchor => Icons.campaign_rounded,
    TtsPreset.natural => Icons.waves_rounded,
    TtsPreset.story => Icons.menu_book_rounded,
  };



  double get speed => switch (this) {
    TtsPreset.anchor => 0.92,
    TtsPreset.natural => 1.0,
    TtsPreset.story => 0.96,
  };

  double get pitch => switch (this) {
    TtsPreset.anchor => 0.91,
    TtsPreset.natural => 1.0,
    TtsPreset.story => 1.07,
  };
}

class TtsSettingsSheet extends ConsumerStatefulWidget {
  const TtsSettingsSheet({this.articleLanguage = 'en', super.key});

  final String articleLanguage;

  @override
  ConsumerState<TtsSettingsSheet> createState() => _TtsSettingsSheetState();
}

class _TtsSettingsSheetState extends ConsumerState<TtsSettingsSheet> {
  double _speed = 1.0;
  double _pitch = 1.0;
  double _volume = 1.0;
  TtsPreset _preset = TtsPreset.natural;

  List<Map<String, String>> _voices = [];
  Map<String, String>? _selected;
  bool _loadingVoices = true;

  @override
  void initState() {
    super.initState();
    _loadPersistedSettings();
    _loadVoices();
  }

  Future<void> _loadPersistedSettings() async {
    final manager = ref.read(ttsManagerProvider);
    final prefs = await SharedPreferences.getInstance();

    final speed = manager.currentSpeed;
    final pitch = manager.currentPitch;
    final preset = manager.currentPreset;

    if (!mounted) return;
    setState(() {
      _speed = speed;
      _pitch = pitch;
      _volume = prefs.getDouble(_kVolume) ?? 1.0;
      _preset = preset;
    });
  }

  Future<void> _loadVoices() async {
    final voices = await ref.read(ttsManagerProvider).getAvailableVoices();

    voices.sort((a, b) {
      final aLang = (a['locale'] ?? '').toLowerCase();
      final bLang = (b['locale'] ?? '').toLowerCase();
      final target = widget.articleLanguage.toLowerCase();
      final aMatch = aLang.startsWith(target);
      final bMatch = bLang.startsWith(target);
      if (aMatch && !bMatch) return -1;
      if (!aMatch && bMatch) return 1;
      return aLang.compareTo(bLang);
    });

    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString(_kVoice);

    Map<String, String>? selected;
    if (savedName != null) {
      selected = voices.firstWhere(
        (v) => v['name'] == savedName,
        orElse: () => voices.isNotEmpty ? voices.first : {},
      );
      if (selected.isEmpty) selected = null;
    }
    selected ??= voices.isNotEmpty ? voices.first : null;

    if (!mounted) return;
    setState(() {
      _voices = voices;
      _selected = selected;
      _loadingVoices = false;
    });
  }


  Future<void> _saveDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _applyPreset(TtsPreset preset) async {
    final manager = ref.read(ttsManagerProvider);
    setState(() {
      _preset = preset;
      _speed = preset.speed;
      _pitch = preset.pitch;
    });

    await manager.setSpeed(preset.speed);
    await manager.setPitch(preset.pitch);
    await manager.setPreset(preset);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final manager = ref.read(ttsManagerProvider);

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surface,
            scheme.surfaceContainerLow,
            scheme.surfaceContainerHigh.withValues(alpha: 0.95),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    color: scheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Premium Voice Studio',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tune delivery style, voice, and timing.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'News Anchor Preset',
              subtitle: 'Switch instantly between broadcast styles.',
              icon: Icons.tune_rounded,
              child: _PresetSelector(
                selected: _preset,
                onSelected: _applyPreset,
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Fine Tuning',
              subtitle: 'Manual controls for precision playback.',
              icon: Icons.equalizer_rounded,
              child: Column(
                children: [
                  _SettingSlider(
                    label: 'Speed',
                    displayValue: '${_speed.toStringAsFixed(2)}x',
                    icon: Icons.speed_rounded,
                    value: _speed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    onChanged: (v) {
                      setState(() => _speed = v);
                      manager.setSpeed(v);
                      unawaited(_saveDouble(_kSpeed, v));
                    },
                    quickValues: const [0.75, 1.0, 1.25, 1.5],
                    quickLabels: const ['0.75x', '1x', '1.25x', '1.5x'],
                    onQuickTap: (v) {
                      setState(() => _speed = v);
                      manager.setSpeed(v);
                      unawaited(_saveDouble(_kSpeed, v));
                      HapticFeedback.selectionClick();
                    },
                  ),
                  _SettingSlider(
                    label: 'Pitch',
                    displayValue: _pitch.toStringAsFixed(2),
                    icon: Icons.multitrack_audio_rounded,
                    value: _pitch,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    onChanged: (v) {
                      setState(() => _pitch = v);
                      manager.setPitch(v);
                      unawaited(_saveDouble(_kPitch, v));
                    },
                  ),
                  _SettingSlider(
                    label: 'Volume',
                    displayValue: '${(_volume * 100).round()}%',
                    icon: Icons.volume_up_rounded,
                    value: _volume,
                    onChanged: (v) {
                      setState(() => _volume = v);
                      manager.setVolume(v);
                      unawaited(_saveDouble(_kVolume, v));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Voice Library',
              subtitle: 'Choose the voice that best fits your content.',
              icon: Icons.record_voice_over_rounded,
              child: _loadingVoices
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _voices.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No voices found on this device.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : _VoiceList(
                      voices: _voices,
                      selected: _selected,
                      articleLanguage: widget.articleLanguage,
                      onSelect: (v) {
                        setState(() => _selected = v);
                        manager.setVoice(v['name']!, v['locale']!);
                        unawaited(_saveString(_kVoice, v['name']!));
                        unawaited(_saveString(_kLocale, v['locale']!));
                        HapticFeedback.selectionClick();
                      },
                    ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Sleep Timer',
              subtitle: 'Stop playback automatically after a set duration.',
              icon: Icons.bedtime_rounded,
              child: _SleepTimerRow(manager: manager),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PresetSelector extends StatelessWidget {
  const _PresetSelector({required this.selected, required this.onSelected});

  final TtsPreset selected;
  final ValueChanged<TtsPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: TtsPreset.values.map((preset) {
        final isActive = selected == preset;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelected(preset),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isActive
                      ? scheme.primaryContainer.withValues(alpha: 0.95)
                      : scheme.surface.withValues(alpha: 0.55),
                  border: Border.all(
                    color: isActive
                        ? scheme.primary.withValues(alpha: 0.75)
                        : scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      preset.icon,
                      size: 18,
                      color: isActive
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preset.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? scheme.primary
                                  : scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            preset.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SettingSlider extends StatelessWidget {
  const _SettingSlider({
    required this.label,
    required this.displayValue,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions = 20,
    this.quickValues,
    this.quickLabels,
    this.onQuickTap,
  });

  final String label;
  final String displayValue;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final List<double>? quickValues;
  final List<String>? quickLabels;
  final ValueChanged<double>? onQuickTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  displayValue,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          if (quickValues != null && quickLabels != null)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: List.generate(quickValues!.length, (i) {
                final isActive = (value - quickValues![i]).abs() < 0.01;
                return GestureDetector(
                  onTap: () => onQuickTap?.call(quickValues![i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? scheme.primary
                          : scheme.surfaceContainerHighest.withValues(
                              alpha: 0.9,
                            ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      quickLabels![i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _VoiceList extends StatelessWidget {
  const _VoiceList({
    required this.voices,
    required this.selected,
    required this.articleLanguage,
    required this.onSelect,
  });

  final List<Map<String, String>> voices;
  final Map<String, String>? selected;
  final String articleLanguage;
  final ValueChanged<Map<String, String>> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = articleLanguage.toLowerCase();

    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: voices.length,
        itemBuilder: (context, i) {
          final voice = voices[i];
          final isActive = selected?['name'] == voice['name'];
          final locale = voice['locale'] ?? '';
          final isMatch = locale.toLowerCase().startsWith(language);

          return ListTile(
            dense: true,
            selected: isActive,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isMatch
                    ? scheme.primaryContainer.withValues(alpha: 0.9)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isMatch
                    ? Icons.language_rounded
                    : Icons.record_voice_over_rounded,
                size: 14,
                color: isMatch ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
            title: Text(
              voice['name'] ?? 'Unknown Voice',
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
            subtitle: Text(locale),
            trailing: isActive
                ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                : null,
            onTap: () => onSelect(voice),
          );
        },
      ),
    );
  }
}

class _SleepTimerRow extends ConsumerWidget {
  const _SleepTimerRow({required this.manager});

  final dynamic manager;

  static const _options = [
    (label: '5m', dur: Duration(minutes: 5)),
    (label: '10m', dur: Duration(minutes: 10)),
    (label: '15m', dur: Duration(minutes: 15)),
    (label: '30m', dur: Duration(minutes: 30)),
    (label: '60m', dur: Duration(minutes: 60)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<Duration?>(
      stream: manager.sleepTimerRemaining as Stream<Duration?>,
      builder: (context, snap) {
        final remaining = snap.data;
        final hasTimer = remaining != null && remaining > Duration.zero;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasTimer)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.bedtime_rounded,
                      size: 16,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Stops in ${_formatRemaining(remaining)}',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        manager.setSleepTimer(Duration.zero);
                        HapticFeedback.selectionClick();
                      },
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: scheme.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _options.map((opt) {
                return ChoiceChip(
                  label: Text(opt.label),
                  selected: false,
                  onSelected: (_) {
                    manager.setSleepTimer(opt.dur);
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  String _formatRemaining(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '${s}s';
  }
}

void unawaited(Future<void> future) {}
