extension StringCasingExtension on String {
  String toCamelCase() {
    if (trim().isEmpty) return '';
    final words = trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '';
    String result = words[0].toLowerCase();
    for (int i = 1; i < words.length; i++) {
      final w = words[i];
      if (w.isNotEmpty) {
        result += w[0].toUpperCase() + w.substring(1).toLowerCase();
      }
    }
    return result;
  }

  String toTitleCase() {
    if (trim().isEmpty) return '';
    return trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
