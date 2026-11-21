import 'package:flutter/material.dart';
import '../utils/icon_value.dart';

// Detects whether a campaign's icon field is a plain emoji character or an image/GIF URL, and
// renders the right thing either way. Image.network already plays animated GIFs natively in
// Flutter — no extra package needed for that part.
class CampaignIcon extends StatelessWidget {
  final String icon;
  final double size;
  const CampaignIcon({super.key, required this.icon, this.size = 26});

  bool get _isUrl => icon.startsWith('http://') || icon.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    if (_isUrl) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: Image.network(
          icon,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Text('🎉', style: TextStyle(fontSize: size)),
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : SizedBox(width: size, height: size, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      );
    }
    // Free-text column: a name, shortcode or codepoint becomes its emoji, anything unknown the
    // fallback — never the raw text.
    return Text(displayIcon(icon), style: TextStyle(fontSize: size));
  }
}
