class VoiceProfile {

  const VoiceProfile({
    required this.name,
    required this.locale,
    this.gender = 'unknown',
    this.isNetworkVoice = false,
  });
  final String name;
  final String locale;
  final String gender;
  final bool isNetworkVoice;
}
