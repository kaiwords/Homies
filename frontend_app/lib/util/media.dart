import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../state/models.dart';

/// We persist chat media as base64 data URLs inside the local store (same as the
/// rest of the app), so keep clips small enough to serialise comfortably.
const int kMaxMediaBytes = 8 * 1024 * 1024; // 8 MB

/// Result of a media capture/pick: either an attachment, nothing (user
/// cancelled), or a human-readable error.
class MediaResult {
  final Attachment? attachment;
  final String? error;
  const MediaResult.ok(this.attachment) : error = null;
  const MediaResult.fail(this.error) : attachment = null;
  bool get cancelled => attachment == null && error == null;
}

final ImagePicker _picker = ImagePicker();

String _extOf(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

String _imageMime(String name) => switch (_extOf(name)) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/heic',
      _ => 'image/jpeg',
    };

String _videoMime(String name) => switch (_extOf(name)) {
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      'mkv' => 'video/x-matroska',
      _ => 'video/mp4',
    };

String _audioMime(String path) => switch (_extOf(path)) {
      'm4a' || 'aac' => 'audio/mp4',
      'wav' => 'audio/wav',
      'opus' || 'ogg' => 'audio/ogg',
      _ => 'audio/mpeg',
    };

String _dataUrl(String mime, List<int> bytes) => 'data:$mime;base64,${base64Encode(bytes)}';

String _tooLarge(String kind, int bytes) =>
    '$kind is ${(bytes / 1024 / 1024).toStringAsFixed(1)} MB — keep it under '
    '${(kMaxMediaBytes / 1024 / 1024).round()} MB.';

/// Pick or capture a photo and return it as a base64 [Attachment].
Future<MediaResult> pickImageAttachment({required bool fromCamera}) async {
  try {
    final x = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 72,
      maxWidth: 1600,
    );
    if (x == null) return const MediaResult.ok(null);
    final bytes = await x.readAsBytes();
    if (bytes.length > kMaxMediaBytes) return MediaResult.fail(_tooLarge('Photo', bytes.length));
    final mime = _imageMime(x.name);
    return MediaResult.ok(Attachment(
      fileName: x.name,
      dataUrl: _dataUrl(mime, bytes),
      type: mime,
      size: bytes.length,
      uploadedAt: DateTime.now().toIso8601String(),
    ));
  } catch (_) {
    return const MediaResult.fail("Couldn't add that photo.");
  }
}

/// Pick or capture a short video and return it as a base64 [Attachment].
Future<MediaResult> pickVideoAttachment({required bool fromCamera}) async {
  try {
    final x = await _picker.pickVideo(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxDuration: const Duration(minutes: 1),
    );
    if (x == null) return const MediaResult.ok(null);
    final bytes = await x.readAsBytes();
    if (bytes.length > kMaxMediaBytes) {
      return MediaResult.fail('${_tooLarge('Video', bytes.length)} Try a shorter clip.');
    }
    final mime = _videoMime(x.name);
    return MediaResult.ok(Attachment(
      fileName: x.name,
      dataUrl: _dataUrl(mime, bytes),
      type: mime,
      size: bytes.length,
      uploadedAt: DateTime.now().toIso8601String(),
    ));
  } catch (_) {
    return const MediaResult.fail("Couldn't add that video.");
  }
}

/// Convert a recorded voice file (from the `record` package) into a base64
/// [Attachment], tagged with its duration.
Future<MediaResult> voiceFileToAttachment(String path, int durationMs) async {
  try {
    final file = File(path);
    final bytes = await file.readAsBytes();
    if (bytes.length > kMaxMediaBytes) return MediaResult.fail(_tooLarge('Recording', bytes.length));
    final mime = _audioMime(path);
    final attachment = Attachment(
      fileName: 'voice-message.${_extOf(path).isEmpty ? 'm4a' : _extOf(path)}',
      dataUrl: _dataUrl(mime, bytes),
      type: mime,
      size: bytes.length,
      uploadedAt: DateTime.now().toIso8601String(),
      durationMs: durationMs,
    );
    try {
      await file.delete();
    } catch (_) {/* best-effort cleanup */}
    return MediaResult.ok(attachment);
  } catch (_) {
    return const MediaResult.fail("Couldn't save that recording.");
  }
}

/// Decode an attachment's base64 data URL back into bytes (for display/playback).
Uint8List? decodeAttachment(Attachment? a) {
  final url = a?.dataUrl;
  if (url == null || !url.startsWith('data:')) return null;
  final comma = url.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(url.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

/// Materialise an attachment to a cached temp file — needed by video_player,
/// which can't play from in-memory bytes. The file name is content-stable so the
/// same clip isn't rewritten on every open.
Future<File?> attachmentToTempFile(Attachment a, {String ext = 'mp4'}) async {
  final bytes = decodeAttachment(a);
  if (bytes == null) return null;
  final dir = await getTemporaryDirectory();
  final key = '${a.size ?? bytes.length}-${a.uploadedAt?.hashCode ?? 0}';
  final f = File('${dir.path}/chat-media-$key.$ext');
  if (!await f.exists()) await f.writeAsBytes(bytes, flush: true);
  return f;
}
