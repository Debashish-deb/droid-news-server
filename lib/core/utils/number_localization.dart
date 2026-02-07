/// Helper utility to convert numbers to Bengali numerals
///
/// Bengali (Bangla) uses Eastern Arabic numerals:
/// ০ ১ ২ ৩ ৪ ৫ ৬ ৭ ৮ ৯
library;

String localizeNumber(dynamic number, String languageCode) {
  if (languageCode != 'bn') {
    return number.toString();
  }

  const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const bengaliDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

  String numberStr = number.toString();
  for (int i = 0; i < englishDigits.length; i++) {
    numberStr = numberStr.replaceAll(englishDigits[i], bengaliDigits[i]);
  }

  return numberStr;
}

/// Extension on num to easily localize numbers
extension NumberLocalization on num {
  String localized(String languageCode) => localizeNumber(this, languageCode);
}
