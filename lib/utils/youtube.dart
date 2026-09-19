// Extracted out of campaign_detail_screen.dart so Town Voice can use the exact same robust
// logic — accepts whatever format actually gets pasted into a database field (a full watch
// link, a youtu.be short link, or a bare video ID) rather than assuming one specific format.
String? extractYoutubeVideoId(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  // Already a bare ID — YouTube IDs are always exactly 11 characters, letters/digits/-/_.
  if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trimmed)) return trimmed;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (uri.host.contains('youtu.be')) {
    // youtu.be/VIDEO_ID — the ID is the first path segment.
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
  }
  if (uri.host.contains('youtube.com')) {
    // youtube.com/watch?v=VIDEO_ID (also handles extra params like &t=10s, since
    // queryParameters parses those out already) or youtube.com/embed|shorts/VIDEO_ID.
    if (uri.queryParameters.containsKey('v')) return uri.queryParameters['v'];
    if (uri.pathSegments.length >= 2 && (uri.pathSegments[0] == 'embed' || uri.pathSegments[0] == 'shorts')) {
      return uri.pathSegments[1];
    }
  }
  return null; // Genuinely unrecognized format — caller shows an honest error rather than guessing.
}
