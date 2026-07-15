import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/media_viewer.dart';
import 'post_thread.dart' show threadMessages;

String _pid(String prefix) =>
    '$prefix-${Random().nextInt(0xFFFFFF).toRadixString(36)}';

String _clock(String iso) {
  final d = parseIso(iso);
  if (d == null) return '';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'am' : 'pm'}';
}

Uint8List? _decodeBytes(Attachment a) {
  final url = a.dataUrl;
  if (url == null || !url.startsWith('data:')) return null;
  final comma = url.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(url.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

/// 1:1 chat between a client and a business's poster, scoped to an
/// EssentialListing. Mirrors PostThreadScreen but with essentials-specific
/// context chrome (no performance-reference chrome, since that's not
/// relevant between a client and a local business).
class EssentialThreadScreen extends StatefulWidget {
  final EssentialListing listing;
  final String otherUserId;
  const EssentialThreadScreen({
    super.key,
    required this.listing,
    required this.otherUserId,
  });

  @override
  State<EssentialThreadScreen> createState() => _EssentialThreadScreenState();
}

class _EssentialThreadScreenState extends State<EssentialThreadScreen> {
  final _draftCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Attachment? _pendingPhoto;

  @override
  void dispose() {
    _draftCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients)
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    });
  }

  void _send(HomiesState state, String otherId) {
    final text = _draftCtrl.text.trim();
    if (text.isEmpty && _pendingPhoto == null) return;
    final cu = state.currentUser!;
    state.mutate(() {
      state.postMessages.add(
        PostMessage(
          id: _pid('pm'),
          listingId: widget.listing.id,
          from: cu.id,
          to: otherId,
          text: text,
          at: DateTime.now().toIso8601String(),
          attachment: _pendingPhoto,
        ),
      );
    });
    _draftCtrl.clear();
    setState(() => _pendingPhoto = null);
    _jumpToEnd();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.bytes == null) return;
    if (f.size > 2 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image too large — keep it under 2 MB.'),
          ),
        );
      }
      return;
    }
    final ext = (f.extension ?? '').toLowerCase();
    final type = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    setState(() {
      _pendingPhoto = Attachment(
        fileName: f.name,
        dataUrl: 'data:$type;base64,${base64Encode(f.bytes!)}',
        type: type,
        size: f.size,
        uploadedAt: DateTime.now().toIso8601String(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final posterId = widget.listing.postedBy;
    final otherId = cu.id == posterId ? widget.otherUserId : posterId;
    final other = state.findUser(otherId);
    final messages = threadMessages(
      state,
      widget.listing.id,
      posterId,
      widget.otherUserId,
    );

    _jumpToEnd();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Avatar.sm(other),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    other?.name ?? 'Conversation',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Re: ${widget.listing.businessName}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: HomiesColors.textDim,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _EssentialContextBar(listing: widget.listing),
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 32,
                            color: HomiesColors.textFaint,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No messages yet — say hi 👋',
                            style: TextStyle(color: HomiesColors.textDim),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      itemCount: messages.length,
                      itemBuilder: (_, i) => _MessageRow(
                        message: messages[i],
                        currentUser: cu,
                        sender: state.findUser(messages[i].from),
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: const BoxDecoration(
                color: HomiesColors.surface,
                border: Border(top: BorderSide(color: HomiesColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pendingPhoto != null)
                    _PendingPhotoPreview(
                      attachment: _pendingPhoto!,
                      onRemove: () => setState(() => _pendingPhoto = null),
                    ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.photo_outlined,
                          size: 22,
                          color: HomiesColors.textDim,
                        ),
                        tooltip: 'Send photo',
                        visualDensity: VisualDensity.compact,

                        onPressed: _pickPhoto,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _draftCtrl,
                          textInputAction: TextInputAction.send,
                          decoration: InputDecoration(
                            hintText: 'Type a message…',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            filled: true,
                            fillColor: HomiesColors.surface2,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _send(state, otherId),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: HomiesColors.accent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _send(state, otherId),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              Icons.send_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EssentialContextBar extends StatelessWidget {
  final EssentialListing listing;
  const _EssentialContextBar({required this.listing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: HomiesColors.surface2,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 16,
            color: HomiesColors.textDim,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              listing.businessName,
              style: const TextStyle(fontSize: 12, color: HomiesColors.textDim),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  final PostMessage message;
  final User currentUser;
  final User? sender;
  const _MessageRow({
    required this.message,
    required this.currentUser,
    required this.sender,
  });

  @override
  Widget build(BuildContext context) {
    final mine = message.from == currentUser.id;
    final align = mine ? MainAxisAlignment.end : MainAxisAlignment.start;

    Widget content;
    if (message.attachment != null) {
      content = _PhotoMessage(
        attachment: message.attachment!,
        text: message.text,
        mine: mine,
        senderName: mine ? null : sender?.name,
      );
    } else {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: mine ? HomiesColors.accent : HomiesColors.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Text(
                sender?.name ?? '—',
                style: const TextStyle(
                  fontSize: 11,
                  color: HomiesColors.textDim,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              message.text,
              style: TextStyle(
                color: mine ? Colors.white : HomiesColors.text,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: align,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!mine) Avatar.sm(sender),
              if (!mine) const SizedBox(width: 6),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.80,
                ),
                child: content,
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 2,
              left: mine ? 0 : 32,
              right: mine ? 2 : 0,
            ),
            child: Text(
              _clock(message.at),
              style: const TextStyle(
                fontSize: 10,
                color: HomiesColors.textFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Strip above the input bar showing the staged photo before it's sent.
class _PendingPhotoPreview extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback onRemove;
  const _PendingPhotoPreview({
    required this.attachment,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeBytes(attachment);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                bytes,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: HomiesColors.surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.image_outlined,
                color: HomiesColors.textFaint,
              ),
            ),
          IconButton(
            icon: const Icon(
              Icons.close,
              size: 16,
              color: HomiesColors.textDim,
            ),
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

/// Chat bubble that shows an image (+ optional caption text below it).
class _PhotoMessage extends StatelessWidget {
  final Attachment attachment;
  final String text;
  final bool mine;
  final String? senderName;
  const _PhotoMessage({
    required this.attachment,
    required this.text,
    required this.mine,
    this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeBytes(attachment);
    final bg = mine ? HomiesColors.accent : HomiesColors.surface2;
    final textColor = mine ? Colors.white : HomiesColors.text;

    return Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (senderName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2, left: 2),
            child: Text(
              senderName!,
              style: const TextStyle(
                fontSize: 11,
                color: HomiesColors.textDim,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        GestureDetector(
          onTap: bytes == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => FullscreenImageViewer(
                      bytes: bytes,
                      fileName: attachment.fileName,
                      mimeType: attachment.type,
                    ),
                  ),
                ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: bytes != null
                ? Image.memory(bytes, width: 220, fit: BoxFit.fitWidth)
                : Container(
                    width: 220,
                    height: 140,
                    color: HomiesColors.surface2,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: HomiesColors.textFaint,
                      size: 40,
                    ),
                  ),
          ),
        ),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(text, style: TextStyle(color: textColor, fontSize: 14)),
          ),
        ],
      ],
    );
  }
}
