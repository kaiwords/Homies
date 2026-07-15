import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme.dart';
import 'ui_kit.dart';

class FilePickerButton extends StatefulWidget {
  final Attachment? value;
  final ValueChanged<Attachment?> onChanged;
  final List<String>? allowedExtensions;
  final String? label;
  const FilePickerButton({
    super.key,
    required this.value,
    required this.onChanged,
    this.allowedExtensions,
    this.label,
  });

  @override
  State<FilePickerButton> createState() => _FilePickerButtonState();
}

class _FilePickerButtonState extends State<FilePickerButton> {
  bool _busy = false;
  String? _error;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: widget.allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: widget.allowedExtensions,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      final f = result.files.first;
      if (f.size > 2 * 1024 * 1024) {
        setState(() {
          _busy = false;
          _error =
              'File is ${(f.size / 1024 / 1024).toStringAsFixed(1)} MB — keep it under 2 MB for the demo.';
        });
        return;
      }
      final bytes = f.bytes;
      String? dataUrl;
      String? type;
      if (bytes != null) {
        final ext = (f.extension ?? '').toLowerCase();
        type = switch (ext) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'png' => 'image/png',
          'gif' => 'image/gif',
          'webp' => 'image/webp',
          'pdf' => 'application/pdf',
          _ => 'application/octet-stream',
        };
        dataUrl = 'data:$type;base64,${base64Encode(bytes)}';
      }
      widget.onChanged(
        Attachment(
          fileName: f.name,
          dataUrl: dataUrl,
          type: type,
          size: f.size,
          uploadedAt: DateTime.now().toIso8601String(),
        ),
      );
      setState(() => _busy = false);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Could not read that file.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.value != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AttachmentTile(value: widget.value!),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextButton(
              onPressed: () => widget.onChanged(null),
              child: const Text('Replace'),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _pick,
          icon: const Icon(Icons.attach_file, size: 18),
          label: Text(_busy ? 'Reading…' : (widget.label ?? 'Choose file')),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _error!,
              style: const TextStyle(color: HomiesColors.danger, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
