import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Strips any directory components from [name], keeping just the basename,
/// so a fileName carrying '../' or an absolute path can't write outside the
/// intended directory.
String _safeFileName(String name) {
  final base = name.split(RegExp(r'[\\/]')).last.trim();
  return base.isEmpty ? 'file' : base;
}

/// Full-screen image viewer with pinch-zoom, explicit back button and download.
/// Use with [Navigator.push] + [fullscreenDialog: true].
class FullscreenImageViewer extends StatelessWidget {
  final Uint8List bytes;
  final String? fileName;
  final String? mimeType;

  const FullscreenImageViewer({
    super.key,
    required this.bytes,
    this.fileName,
    this.mimeType,
  });

  Future<void> _save(BuildContext context) async {
    try {
      final dir = await getTemporaryDirectory();
      final name = _safeFileName(fileName ?? 'photo-${DateTime.now().millisecondsSinceEpoch}.jpg');
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path, mimeType: mimeType ?? 'image/jpeg')]);
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
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Save photo',
            onPressed: () => _save(context),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 6,
          child: Image.memory(bytes),
        ),
      ),
    );
  }
}
