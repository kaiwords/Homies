import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homies_mobile/state/models.dart';
import 'package:homies_mobile/util/media.dart';

void main() {
  group('Attachment Storage fields', () {
    test('url and storagePath round-trip through JSON', () {
      final a = Attachment(
        fileName: 'photo.jpg',
        url: 'https://storage.example/media/u1/abc.jpg',
        storagePath: 'media/u1/abc.jpg',
        type: 'image/jpeg',
        size: 1234,
        uploadedAt: '2026-01-01T00:00:00',
      );
      final decoded =
          Attachment.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>)!;
      expect(decoded.url, a.url);
      expect(decoded.storagePath, a.storagePath);
      expect(decoded.dataUrl, isNull); // Storage-backed → no inline base64
    });
  });

  group('attachmentImageProvider', () {
    test('prefers the Storage url (NetworkImage) over base64', () {
      final a = Attachment(
        url: 'https://storage.example/media/u1/abc.jpg',
        // Even if a legacy dataUrl were present, url wins:
        dataUrl: 'data:image/png;base64,${base64Encode(const [1, 2, 3, 4])}',
        type: 'image/jpeg',
      );
      expect(attachmentImageProvider(a), isA<NetworkImage>());
    });

    test('falls back to the legacy base64 dataUrl (MemoryImage)', () {
      final a = Attachment(
        dataUrl: 'data:image/png;base64,${base64Encode(const [1, 2, 3, 4])}',
        type: 'image/png',
      );
      expect(attachmentImageProvider(a), isA<MemoryImage>());
    });

    test('returns null when neither url nor decodable dataUrl is present', () {
      expect(attachmentImageProvider(Attachment(type: 'image/png')), isNull);
      expect(attachmentImageProvider(null), isNull);
    });
  });
}
