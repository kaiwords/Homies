import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../state/models.dart';

/// Media bytes are uploaded to Firebase Storage and only a download URL is kept
/// in the synced doc (see [Attachment.url]). We still cap the size so uploads
/// stay quick and stay under the Storage rule's 10 MB write limit; when there's
/// no signed-in Firebase user (demo/offline) we fall back to an inline base64
/// data URL, so keep clips small enough to serialise comfortably too.
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

const _uuid = Uuid();

/// Upload [bytes] to Firebase Storage under `media/{uid}/{uuid}.{ext}` with the
/// given content-type, and return its download URL + object path. Returns null
/// when there's no signed-in Firebase user (demo/offline) or the upload throws,
/// so callers can fall back to an inline base64 [Attachment.dataUrl].
Future<({String url, String storagePath})?> _uploadToStorage(
  List<int> bytes, {
  required String mime,
  required String ext,
}) async {
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  try {
    final path = 'media/$uid/${_uuid.v4()}.$ext';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(contentType: mime),
    );
    final url = await ref.getDownloadURL();
    return (url: url, storagePath: path);
  } catch (_) {
    return null;
  }
}

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
    final ext = _extOf(x.name).isEmpty ? 'jpg' : _extOf(x.name);
    // Try Storage first so the synced doc only carries a tiny URL; fall back to
    // an inline base64 data URL for demo/offline (no Firebase user) or on error.
    final uploaded = await _uploadToStorage(bytes, mime: mime, ext: ext);
    return MediaResult.ok(Attachment(
      fileName: x.name,
      url: uploaded?.url,
      storagePath: uploaded?.storagePath,
      dataUrl: uploaded == null ? _dataUrl(mime, bytes) : null,
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
    final ext = _extOf(x.name).isEmpty ? 'mp4' : _extOf(x.name);
    final uploaded = await _uploadToStorage(bytes, mime: mime, ext: ext);
    return MediaResult.ok(Attachment(
      fileName: x.name,
      url: uploaded?.url,
      storagePath: uploaded?.storagePath,
      dataUrl: uploaded == null ? _dataUrl(mime, bytes) : null,
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
    final ext = _extOf(path).isEmpty ? 'm4a' : _extOf(path);
    final uploaded = await _uploadToStorage(bytes, mime: mime, ext: ext);
    final attachment = Attachment(
      fileName: 'voice-message.$ext',
      url: uploaded?.url,
      storagePath: uploaded?.storagePath,
      dataUrl: uploaded == null ? _dataUrl(mime, bytes) : null,
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

/// Decode an attachment's legacy base64 data URL back into bytes (for
/// display/playback of pre-Phase-3 / demo attachments). Returns null for
/// Storage-backed attachments, which carry their bytes at [Attachment.url].
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

/// Central image display helper so the ~11 display sites don't each duplicate
/// the url-vs-base64 branching. Prefers the Storage [Attachment.url]
/// ([NetworkImage]); falls back to the legacy base64 [Attachment.dataUrl]
/// ([MemoryImage]); returns null when neither is usable (caller shows a
/// placeholder).
ImageProvider? attachmentImageProvider(Attachment? a) {
  if (a == null) return null;
  final url = a.url;
  if (url != null && url.isNotEmpty) return NetworkImage(url);
  final bytes = decodeAttachment(a);
  if (bytes != null) return MemoryImage(bytes);
  return null;
}

/// Materialise an attachment to a cached temp file — needed by video_player /
/// share, which can't work from in-memory bytes. For Storage-backed
/// attachments (url set, no dataUrl) the bytes are downloaded over HTTP;
/// otherwise the legacy base64 path is decoded. The file name is content-stable
/// so the same clip isn't rewritten on every open.
Future<File?> attachmentToTempFile(Attachment a, {String ext = 'mp4'}) async {
  Uint8List? bytes = decodeAttachment(a);
  if (bytes == null) {
    final url = a.url;
    if (url == null || url.isEmpty) return null;
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) return null;
      bytes = resp.bodyBytes;
    } catch (_) {
      return null;
    }
  }
  final dir = await getTemporaryDirectory();
  final key = '${a.storagePath?.hashCode ?? 0}-${a.size ?? bytes.length}-${a.uploadedAt?.hashCode ?? 0}';
  final f = File('${dir.path}/chat-media-$key.$ext');
  if (!await f.exists()) await f.writeAsBytes(bytes, flush: true);
  return f;
}
