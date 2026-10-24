/// Splits a reply into pieces a voice can speak one after another: sentence by sentence, so the
/// first words start quickly and the next piece is made while the current one plays.
/// Markdown marks, links and emoji-like symbols are dropped because they are read out badly.
List<String> speechChunks(String text, {int maxChars = 200}) {
  var t = text
      .replaceAll(RegExp(r'https?://\S+'), '')
      .replaceAll(RegExp(r'[*_`#>~|]+'), '')
      .replaceAll(RegExp(r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}]', unicode: true), '')
      // A line break after punctuation is just a space; after a bare line it becomes a full stop.
      .replaceAllMapped(RegExp(r'([:;,.!?…])\s*\n+\s*'), (m) => '${m[1]} ')
      .replaceAll(RegExp(r'\s*\n+\s*'), '. ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (t.isEmpty) return const [];

  // Break after . ! ? (and the ellipsis) that is followed by a space.
  final sentences = <String>[];
  var start = 0;
  for (final m in RegExp(r'[.!?…]+["”)]*\s+').allMatches(t)) {
    sentences.add(t.substring(start, m.end).trim());
    start = m.end;
  }
  if (start < t.length) sentences.add(t.substring(start).trim());

  // Very short pieces ("Okay.") join the next one so the voice does not stutter.
  final merged = <String>[];
  for (final s in sentences.where((s) => s.isNotEmpty)) {
    if (merged.isNotEmpty && merged.last.length < 14) {
      merged[merged.length - 1] = '${merged.last} $s';
    } else {
      merged.add(s);
    }
  }

  // An overlong piece is cut at a comma, or at a space if it has none.
  final out = <String>[];
  for (final s in merged) {
    var rest = s;
    while (rest.length > maxChars) {
      var cut = rest.lastIndexOf(RegExp(r'[,;:]\s'), maxChars);
      if (cut < maxChars ~/ 3) cut = rest.lastIndexOf(' ', maxChars);
      if (cut < 1) cut = maxChars;
      out.add(rest.substring(0, cut + 1).trim());
      rest = rest.substring(cut + 1).trim();
    }
    if (rest.isNotEmpty) out.add(rest);
  }
  return out;
}
