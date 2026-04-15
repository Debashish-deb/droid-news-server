import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/tts/domain/entities/tts_state.dart';
import '../../../../core/tts/presentation/providers/tts_controller.dart';
import '../../../providers/feature_providers.dart';
import '../domain/models/tts_runtime_diagnostics.dart';
import '../services/tts_prosody_builder.dart';
import '../services/tts_preference_keys.dart';
import '../services/tts_providers.dart';
import '../../../../core/tts/shared/tts_voice_heuristics.dart';

extension _TtsPresetUi on TtsPreset {
  String get label => switch (this) {
    TtsPreset.anchor => 'Anchor',
    TtsPreset.natural => 'Natural',
    TtsPreset.story => 'Story',
  };

  IconData get icon => switch (this) {
    TtsPreset.anchor => Icons.campaign_rounded,
    TtsPreset.natural => Icons.waves_rounded,
    TtsPreset.story => Icons.menu_book_rounded,
  };

  double get speed => switch (this) {
    TtsPreset.anchor => 0.98,
    TtsPreset.natural => 1.0,
    TtsPreset.story => 0.96,
  };

  double get pitch => switch (this) {
    TtsPreset.anchor => 0.98,
    TtsPreset.natural => 1.0,
    TtsPreset.story => 1.03,
  };
}

class TtsSettingsSheet extends ConsumerStatefulWidget {
  const TtsSettingsSheet({
    this.articleLanguage = 'en',
    this.showAutoPlayControls = true,
    super.key,
  });

  final String articleLanguage;
  final bool showAutoPlayControls;

  @override
  ConsumerState<TtsSettingsSheet> createState() => _TtsSettingsSheetState();
}

class _TtsSettingsSheetState extends ConsumerState<TtsSettingsSheet> {
  double _speed = 1.0;
  double _pitch = 1.0;
  double _volume = 1.0;
  TtsPreset _preset = TtsPreset.natural;
  bool _autoPlayNextArticle = false;

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
    final manager = ref.read(appTtsCoordinatorProvider);
    final prefs = await SharedPreferences.getInstance();
    final speed = manager.currentSpeed;
    final pitch = manager.currentPitch;
    final preset = manager.currentPreset;
    if (!mounted) return;
    setState(() {
      _speed = speed;
      _pitch = pitch;
      _volume = prefs.getDouble(TtsPreferenceKeys.volume) ?? 1.0;
      _preset = preset;
      _autoPlayNextArticle =
          prefs.getBool(TtsPreferenceKeys.autoPlayNextArticle) ?? false;
    });
  }

  Future<void> _loadVoices() async {
    final voices = TtsVoiceHeuristics.sortVoiceMaps(
      await ref.read(appTtsCoordinatorProvider).getAvailableVoices(),
      preferredLanguageCode: widget.articleLanguage,
    );

    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString(TtsPreferenceKeys.voiceName);

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

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _applyPreset(TtsPreset preset) async {
    final manager = ref.read(appTtsCoordinatorProvider);
    setState(() {
      _preset = preset;
      _speed = preset.speed;
      _pitch = preset.pitch;
    });
    await manager.setSpeed(preset.speed);
    await manager.setPitch(preset.pitch);
    await manager.setPreset(preset);
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final manager = ref.read(appTtsCoordinatorProvider);
    final ttsState = ref.watch(ttsControllerProvider);
    final diagnosticsAsync = ref.watch(ttsDiagnosticsProvider);
    final diagnostics = diagnosticsAsync.value ?? manager.currentDiagnostics;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            color: scheme.surface,
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.22),
                blurRadius: 36,
                offset: const Offset(0, -12),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Drag handle ──────────────────────────────────
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // ── Header ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [scheme.primary, scheme.tertiary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.graphic_eq_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Voice Studio',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Customize reading style & voice',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, indent: 20, endIndent: 20),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    bottomInset + bottomPadding + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _VoiceStudioSummaryCard(
                        ttsState: ttsState,
                        diagnostics: diagnostics,
                        selectedVoice: _selected,
                        preset: _preset,
                        speed: _speed,
                        onRetry: ref.read(ttsControllerProvider.notifier).retry,
                      ),
                      const SizedBox(height: 20),

                      if (widget.showAutoPlayControls) ...[
                        _sectionLabel(context, 'Playback Mode'),
                        const SizedBox(height: 10),
                        _AutoPlayModeCard(
                          autoPlayNextArticle: _autoPlayNextArticle,
                          onChanged: (enabled) {
                            setState(() => _autoPlayNextArticle = enabled);
                            unawaited(
                              _saveBool(
                                TtsPreferenceKeys.autoPlayNextArticle,
                                enabled,
                              ),
                            );
                            HapticFeedback.selectionClick();
                          },
                        ),
                        const SizedBox(height: 20),
                      ],

                      _sectionLabel(context, 'Broadcast Style'),
                      const SizedBox(height: 10),
                      _ThumbPresetRow(
                        selected: _preset,
                        onSelected: _applyPreset,
                      ),

                      const SizedBox(height: 20),

                      _sectionLabel(context, 'Playback Speed'),
                      const SizedBox(height: 10),
                      _ThumbSlider(
                        value: _speed,
                        min: 0.5,
                        max: 2.0,
                        divisions: 30,
                        displayValue: '${_speed.toStringAsFixed(2)}×',
                        icon: Icons.speed_rounded,
                        quickValues: const [0.75, 1.0, 1.25, 1.5],
                        quickLabels: const ['0.75×', '1×', '1.25×', '1.5×'],
                        onChanged: (v) {
                          setState(() => _speed = v);
                          manager.setSpeed(v);
                          unawaited(
                            _saveDouble(TtsPreferenceKeys.playbackSpeed, v),
                          );
                        },
                        onQuickTap: (v) {
                          setState(() => _speed = v);
                          manager.setSpeed(v);
                          unawaited(
                            _saveDouble(TtsPreferenceKeys.playbackSpeed, v),
                          );
                          HapticFeedback.selectionClick();
                        },
                      ),

                      const SizedBox(height: 16),

                      _sectionLabel(context, 'Voice Pitch'),
                      const SizedBox(height: 10),
                      _ThumbSlider(
                        value: _pitch,
                        min: 0.9,
                        max: 1.08,
                        divisions: 18,
                        displayValue: _pitch.toStringAsFixed(2),
                        icon: Icons.multitrack_audio_rounded,
                        onChanged: (v) {
                          setState(() => _pitch = v);
                          manager.setPitch(v);
                          unawaited(_saveDouble(TtsPreferenceKeys.pitch, v));
                        },
                      ),

                      const SizedBox(height: 16),

                      _sectionLabel(context, 'Volume'),
                      const SizedBox(height: 10),
                      _ThumbSlider(
                        value: _volume,
                        displayValue: '${(_volume * 100).round()}%',
                        icon: Icons.volume_up_rounded,
                        onChanged: (v) {
                          setState(() => _volume = v);
                          manager.setVolume(v);
                          unawaited(_saveDouble(TtsPreferenceKeys.volume, v));
                        },
                      ),

                      const SizedBox(height: 20),

                      _sectionLabel(context, 'Voice'),
                      const SizedBox(height: 10),
                      if (_loadingVoices)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_voices.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No voices found on this device.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        _ThumbVoiceList(
                          voices: _voices,
                          selected: _selected,
                          articleLanguage: widget.articleLanguage,
                          onSelect: (v) {
                            setState(() => _selected = v);
                            manager.setVoice(v['name']!, v['locale']!);
                            unawaited(
                              _saveString(
                                TtsPreferenceKeys.voiceName,
                                v['name']!,
                              ),
                            );
                            unawaited(
                              _saveString(
                                TtsPreferenceKeys.voiceLocale,
                                v['locale']!,
                              ),
                            );
                            HapticFeedback.selectionClick();
                          },
                        ),

                      const SizedBox(height: 20),

                      _sectionLabel(context, 'Sleep Timer'),
                      const SizedBox(height: 10),
                      _ThumbSleepTimer(manager: manager),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Reader-only Auto / Manual playback mode
// ─────────────────────────────────────────────────────────
class _AutoPlayModeCard extends StatelessWidget {
  const _AutoPlayModeCard({
    required this.autoPlayNextArticle,
    required this.onChanged,
  });

  final bool autoPlayNextArticle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: autoPlayNextArticle
            ? scheme.primaryContainer.withValues(alpha: 0.68)
            : scheme.surfaceContainerHigh.withValues(alpha: 0.72),
        border: Border.all(
          color: autoPlayNextArticle
              ? scheme.primary.withValues(alpha: 0.72)
              : scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: autoPlayNextArticle
                  ? scheme.primary.withValues(alpha: 0.16)
                  : scheme.onSurfaceVariant.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              autoPlayNextArticle
                  ? Icons.playlist_play_rounded
                  : Icons.touch_app_rounded,
              color: autoPlayNextArticle
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  autoPlayNextArticle ? 'Auto next article' : 'Manual',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  autoPlayNextArticle
                      ? 'After a short pause, Reader TTS announces and starts the next feed article.'
                      : 'TTS stops when the current article finishes.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(value: autoPlayNextArticle, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Thumb-friendly Preset Row (horizontal cards)
// ─────────────────────────────────────────────────────────
class _ThumbPresetRow extends StatelessWidget {
  const _ThumbPresetRow({required this.selected, required this.onSelected});

  final TtsPreset selected;
  final ValueChanged<TtsPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final itemWidth = compact
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 16) / 3;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TtsPreset.values.map((preset) {
            final isActive = selected == preset;
            return SizedBox(
              width: itemWidth,
              child: GestureDetector(
                onTap: () => onSelected(preset),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isActive
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHigh,
                    border: Border.all(
                      color: isActive
                          ? scheme.primary
                          : scheme.outlineVariant.withValues(alpha: 0.5),
                      width: isActive ? 1.5 : 1.0,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        preset.icon,
                        size: 24,
                        color: isActive
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        preset.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isActive ? scheme.primary : scheme.onSurface,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: 20,
                          height: 3,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// Thumb-friendly Slider
// ─────────────────────────────────────────────────────────
class _ThumbSlider extends StatelessWidget {
  const _ThumbSlider({
    required this.value,
    required this.displayValue,
    required this.icon,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions = 20,
    this.quickValues,
    this.quickLabels,
    this.onQuickTap,
  });

  final double value;
  final String displayValue;
  final IconData icon;
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

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 10),
              // Value pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  displayValue,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
              activeTrackColor: scheme.primary,
              inactiveTrackColor: scheme.outlineVariant.withValues(alpha: 0.4),
              thumbColor: scheme.primary,
              overlayColor: scheme.primary.withValues(alpha: 0.12),
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
              runSpacing: 8,
              children: List.generate(quickValues!.length, (i) {
                final isActive = (value - quickValues![i]).abs() < 0.01;
                return GestureDetector(
                  onTap: () => onQuickTap?.call(quickValues![i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
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

// ─────────────────────────────────────────────────────────
// Thumb-friendly Voice List (full-width tiles, no tiny box)
// ─────────────────────────────────────────────────────────
class _ThumbVoiceList extends StatelessWidget {
  const _ThumbVoiceList({
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
    final theme = Theme.of(context);
    final language = articleLanguage.toLowerCase();
    // Show at most 8 voices to avoid infinite scroll; show all matching first
    final display = voices.length > 12 ? voices.sublist(0, 12) : voices;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: display.asMap().entries.map((entry) {
            final i = entry.key;
            final voice = entry.value;
            final isActive = selected?['name'] == voice['name'];
            final locale = voice['locale'] ?? '';
            final isMatch = locale.toLowerCase().startsWith(language);
            final isLast = i == display.length - 1;

            return Column(
              children: [
                Material(
                  color: isActive
                      ? scheme.primaryContainer.withValues(alpha: 0.5)
                      : Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelect(voice),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isMatch
                                  ? scheme.primaryContainer
                                  : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isMatch
                                  ? Icons.language_rounded
                                  : Icons.record_voice_over_rounded,
                              size: 16,
                              color: isMatch
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  voice['name'] ?? 'Unknown Voice',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isActive
                                        ? scheme.primary
                                        : scheme.onSurface,
                                  ),
                                ),
                                Text(
                                  locale,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isActive)
                            Icon(
                              Icons.check_circle_rounded,
                              color: scheme.primary,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Thumb-friendly Sleep Timer
// ─────────────────────────────────────────────────────────
class _ThumbSleepTimer extends ConsumerWidget {
  const _ThumbSleepTimer({required this.manager});

  final dynamic manager;

  static const _options = [
    (label: '5 min', dur: Duration(minutes: 5)),
    (label: '10 min', dur: Duration(minutes: 10)),
    (label: '15 min', dur: Duration(minutes: 15)),
    (label: '30 min', dur: Duration(minutes: 30)),
    (label: '1 hour', dur: Duration(minutes: 60)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return StreamBuilder<Duration?>(
      stream: manager.sleepTimerRemaining as Stream<Duration?>,
      builder: (context, snap) {
        final remaining = snap.data;
        final hasTimer = remaining != null && remaining > Duration.zero;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasTimer)
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;
                  final timerSummary = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bedtime_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Stops in ${_formatRemaining(remaining)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  );
                  final cancelButton = TextButton.icon(
                    onPressed: () {
                      manager.setSleepTimer(Duration.zero);
                      HapticFeedback.mediumImpact();
                    },
                    icon: Icon(
                      Icons.cancel_outlined,
                      size: 16,
                      color: scheme.error,
                    ),
                    label: Text(
                      'Cancel',
                      style: TextStyle(
                        color: scheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      minimumSize: const Size(64, 44),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: compact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              timerSummary,
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: cancelButton,
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: timerSummary),
                              const SizedBox(width: 8),
                              cancelButton,
                            ],
                          ),
                  );
                },
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _options
                  .map((opt) {
                    return GestureDetector(
                      onTap: () {
                        manager.setSleepTimer(opt.dur);
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bedtime_outlined,
                              size: 16,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              opt.label,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        );
      },
    );
  }

  String _formatRemaining(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _VoiceStudioSummaryCard extends StatelessWidget {
  const _VoiceStudioSummaryCard({
    required this.ttsState,
    required this.diagnostics,
    required this.selectedVoice,
    required this.preset,
    required this.speed,
    required this.onRetry,
  });

  final TtsState ttsState;
  final TtsRuntimeDiagnostics diagnostics;
  final Map<String, String>? selectedVoice;
  final TtsPreset preset;
  final double speed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isError = ttsState.status == TtsStatus.error || diagnostics.hasError;
    final chips = <String>[
      'Style: ${preset.label}',
      'Speed: ${speed.toStringAsFixed(2)}×',
      'Voice: ${selectedVoice?['name'] ?? 'System auto'}',
      if ((diagnostics.synthesisStrategy ?? '').isNotEmpty)
        diagnostics.synthesisStrategy!.replaceAll('_', ' '),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primaryContainer.withValues(alpha: 0.78),
                scheme.secondaryContainer.withValues(alpha: 0.72),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isError
                                ? scheme.errorContainer
                                : scheme.surface.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isError
                                ? Icons.error_outline_rounded
                                : Icons.tune_rounded,
                            color: isError ? scheme.error : scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isError ? 'Playback health' : 'Studio ready',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                isError
                                    ? (ttsState.error ??
                                          diagnostics.lastError ??
                                          'TTS hit a recoverable issue.')
                                    : (diagnostics.message ??
                                          'Optimized for phone playback'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isError) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ),
                    ],
                  ],
                )
              else
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isError
                            ? scheme.errorContainer
                            : scheme.surface.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isError
                            ? Icons.error_outline_rounded
                            : Icons.tune_rounded,
                        color: isError ? scheme.error : scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isError ? 'Playback health' : 'Studio ready',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            isError
                                ? (ttsState.error ??
                                      diagnostics.lastError ??
                                      'TTS hit a recoverable issue.')
                                : (diagnostics.message ??
                                      'Optimized for phone playback'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (isError)
                      FilledButton.tonalIcon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips
                    .map(
                      (chip) => ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth - 12,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            chip,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              if (isError &&
                  ((diagnostics.requestedOutputPath ?? '').isNotEmpty ||
                      (diagnostics.resolvedOutputPath ?? '').isNotEmpty)) ...[
                const SizedBox(height: 12),
                Text(
                  diagnostics.requestedOutputPath ??
                      diagnostics.resolvedOutputPath!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// Helper: _formatRemaining (top-level for _SleepTimerRow)
// ─────────────────────────────────────────────────────────
// ignore: unused_element
String _formatRemaining(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}
