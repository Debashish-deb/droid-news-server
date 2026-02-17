class SentenceTokenizer {
  static List<String> tokenize(String text) {
    if (text.isEmpty) return [];
    
    // Split by sentence endings followed by whitespace
    // Handles punctuation like . ! ?
    final cleanedText = text;
    
    // Split by sentence endings followed by whitespace
    // Handles punctuation like . ! ? ।
    return cleanedText
        .split(RegExp(r'(?<=[.!?।])\s+'))
        .where((s) => s.trim().length > 2) // Filter out very short segments
        .toList();
  }
}
