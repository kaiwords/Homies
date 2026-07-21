import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../state/models.dart';
import '../util/media.dart';

/// Full-screen image viewer with pinch-zoom, explicit back button and download.
/// Use with [Navigator.push] + [fullscreenDialog: true]. Works for both
/// Storage-backed ([Attachment.url]) and legacy base64 ([Attachment.dataUrl])
/// attachments — display goes through [attachmentImageProvider] and saving
/// through [attachmentToTempFile] (which downloads the url when needed).
class FullscreenImageViewer extends StatelessWidget {
  final Attachment attachment;

  const FullscreenImageViewer({super.key, required this.attachment});

  String get _ext {
    final name = attachment.fileName ?? '';
    final dot = name.lastIndexOf('.');
    if (dot >= 0 && dot < name.length - 1) return name.substring(dot + 1).toLowerCase();
    return (attachment.type ?? '').contains('png') ? 'png' : 'jpg';
  }

  Future<void> _save(BuildContext context) async {
    try {
      final file = await attachmentToTempFile(attachment, ext: _ext);
      if (file == null) throw Exception('no bytes');
      await Share.shareXFiles([XFile(file.path, mimeType: attachment.type ?? 'image/jpeg')]);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save photo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = attachmentImageProvider(attachment);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (provider != null)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Save photo',
              onPressed: () => _save(context),
            ),
        ],
      ),
      body: Center(
        child: provider == null
            ? const Text('Could not load this photo.', style: TextStyle(color: Colors.white70))
            : InteractiveViewer(
                minScale: 0.5,
                maxScale: 6,
                child: Image(image: provider),
              ),
      ),
    );
  }
}
