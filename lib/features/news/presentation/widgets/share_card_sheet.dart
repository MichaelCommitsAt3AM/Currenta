// lib/features/news/presentation/widgets/share_card_sheet.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/news_article.dart';
import '../../../../core/config/app_config.dart';
import 'share_card.dart';

/// Bottom sheet that previews the [ShareCard] for an article and shares it
/// as an image (+ a Play Store download CTA in the share text) once the
/// user taps Share. Previewing first — rather than capturing a hidden
/// widget behind the scenes — means what the user sees is exactly what
/// gets shared, including e.g. the cover image still loading in on a slow
/// connection.
class ShareCardSheet extends StatefulWidget {
  const ShareCardSheet({super.key, required this.article});

  final NewsArticle article;

  @override
  State<ShareCardSheet> createState() => _ShareCardSheetState();
}

class _ShareCardSheetState extends State<ShareCardSheet> {
  final _boundaryKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _share() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final boundary =
          _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // pixelRatio 3 turns the 360x450 logical card into a ~1080x1350 PNG.
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/currenta_share_${widget.article.id}.png');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.of(context).pop();

      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'To read more news like this, download the app:\n${AppConfig.playStoreUrl}',
        subject: widget.article.title,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create share image: $e')),
      );
      setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF262A3E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: RepaintBoundary(
                key: _boundaryKey,
                child: ShareCard(article: widget.article),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSharing ? null : _share,
                icon: _isSharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.ios_share_rounded),
                label: Text(_isSharing ? 'Preparing...' : 'Share'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
