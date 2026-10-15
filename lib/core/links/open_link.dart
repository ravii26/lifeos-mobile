import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/guide/guide_style.dart';

/// Opens a saved video or link in its own app (YouTube, Instagram) or the
/// browser. Says so plainly when it can't.
Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  final ok = uri != null && uri.hasScheme && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open that link.")));
  }
}

/// "Open video" (or "Open link") for anything made from a save.
class OpenSourceButton extends StatelessWidget {
  final String url;
  const OpenSourceButton(this.url, {super.key});

  static bool _isVideo(String url) => RegExp(r'youtu\.?be|instagram\.com|tiktok\.com|vimeo\.com', caseSensitive: false).hasMatch(url);

  static String _site(String url) {
    final host = Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? '';
    if (host.contains('youtu')) return 'YouTube';
    if (host.contains('instagram')) return 'Instagram';
    return host;
  }

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => openLink(context, url),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Icon(_isVideo(url) ? Icons.play_circle_outline : Icons.open_in_new, size: 20, color: G.accent),
            const SizedBox(width: 10),
            Text(_isVideo(url) ? 'Open video' : 'Open link', style: G.text(15, w: FontWeight.w500, color: G.accent)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_site(url), style: G.label(size: 12, color: G.faint), overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      );
}
