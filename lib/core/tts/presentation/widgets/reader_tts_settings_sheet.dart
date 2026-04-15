import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../presentation/features/tts/ui/tts_settings_sheet.dart';
import '../providers/tts_controller.dart';

class ReaderTtsSettingsSheet extends ConsumerWidget {
  const ReaderTtsSettingsSheet({this.showAutoPlayControls = true, super.key});

  final bool showAutoPlayControls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ttsControllerProvider);
    return TtsSettingsSheet(
      articleLanguage: state.language,
      showAutoPlayControls: showAutoPlayControls,
    );
  }
}
