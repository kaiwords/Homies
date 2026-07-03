import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/media.dart';
import 'media_viewer.dart';

/// Inline photo bubble — a rounded thumbnail that opens a pinch-to-zoom viewer.
class ChatImageBubble extends StatelessWidget {
  final Attachment media;
  final String? caption;
  final bool mine;
  const ChatImageBubble({super.key, required this.media, this.caption, required this.mine});

  @override
  Widget build(BuildContext context) {
    final bytes = decodeAttachment(media);
    if (bytes == null) {
      return Text('🖼️ photo', style: TextStyle(color: mine ? Colors.white : HomiesColors.text));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => FullscreenImageViewer(
            bytes: bytes,
            fileName: media.fileName,
            mimeType: media.type,
          ),
        )),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 240),
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
        ),
      ),
      if (caption != null && caption!.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(caption!, style: TextStyle(color: mine ? Colors.white : HomiesColors.text, fontSize: 14)),
        ),
    ]);
  }
}


/// Video bubble — a dark card with a play badge and duration. Tapping opens a
/// fullscreen player.
class ChatVideoBubble extends StatelessWidget {
  final Attachment media;
  final String? caption;
  final bool mine;
  const ChatVideoBubble({super.key, required this.media, this.caption, required this.mine});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _VideoViewer(media: media),
        )),
        child: Container(
          width: 220,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(alignment: Alignment.center, children: [
            const Icon(Icons.videocam_outlined, color: Colors.white24, size: 64),
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 34),
            ),
            if (media.durationMs != null)
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                  child: Text(fmtDuration(media.durationMs),
                      style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
          ]),
        ),
      ),
      if (caption != null && caption!.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(caption!, style: TextStyle(color: mine ? Colors.white : HomiesColors.text, fontSize: 14)),
        ),
    ]);
  }
}

class _VideoViewer extends StatefulWidget {
  final Attachment media;
  const _VideoViewer({required this.media});

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ext = (widget.media.type ?? '').contains('quicktime') ? 'mov' : 'mp4';
      final file = await attachmentToTempFile(widget.media, ext: ext);
      if (file == null) {
        setState(() => _error = 'Could not load this video.');
        return;
      }
      final c = VideoPlayerController.file(File(file.path));
      await c.initialize();
      await c.setLooping(true);
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() => _controller = c);
      c.play();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not play this video.');
    }
  }

  Future<void> _download(BuildContext context) async {
    try {
      final ext = (widget.media.type ?? '').contains('quicktime') ? 'mov' : 'mp4';
      final file = await attachmentToTempFile(widget.media, ext: ext);
      if (file == null) return;
      await Share.shareXFiles([XFile(file.path, mimeType: widget.media.type ?? 'video/mp4')]);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save video.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (c != null)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Save video',
              onPressed: () => _download(context),
            ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
          : c == null
              ? const Center(child: CircularProgressIndicator(color: Colors.white54))
              : Stack(fit: StackFit.expand, children: [
                  GestureDetector(
                    onTap: () => setState(() => c.value.isPlaying ? c.pause() : c.play()),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
                        child: VideoPlayer(c),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _VideoControls(controller: c),
                  ),
                ]),
    );
  }
}

class _VideoControls extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoControls({required this.controller});

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final v = c.value;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        VideoProgressIndicator(
          c,
          allowScrubbing: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          colors: const VideoProgressColors(
            playedColor: Colors.white,
            bufferedColor: Colors.white38,
            backgroundColor: Colors.white12,
          ),
        ),
        Row(children: [
          InkWell(
            onTap: () => v.isPlaying ? c.pause() : c.play(),
            child: Icon(
              v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${_fmt(v.position)} / ${_fmt(v.duration)}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ]),
      ]),
    );
  }
}

/// Voice-note bubble — play/pause with a scrubbable progress bar and duration.
class ChatVoiceBubble extends StatefulWidget {
  final Attachment media;
  final bool mine;
  const ChatVoiceBubble({super.key, required this.media, required this.mine});

  @override
  State<ChatVoiceBubble> createState() => _ChatVoiceBubbleState();
}

class _ChatVoiceBubbleState extends State<ChatVoiceBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _total = Duration(milliseconds: widget.media.durationMs ?? 0);
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted && d > Duration.zero) setState(() => _total = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    final bytes = decodeAttachment(widget.media);
    if (bytes == null) return;
    if (!_loaded) {
      await _player.setSourceBytes(bytes, mimeType: widget.media.type);
      _loaded = true;
    }
    await _player.resume();
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.mine;
    final fg = mine ? const Color(0xFF1E2A3A) : HomiesColors.text;
    final track = mine ? const Color(0xFF1E2A3A).withValues(alpha: 0.22) : HomiesColors.border;
    final fill = mine ? const Color(0xFF1E2A3A).withValues(alpha: 0.7) : HomiesColors.accent;
    final total = _total.inMilliseconds == 0 ? (widget.media.durationMs ?? 1) : _total.inMilliseconds;
    final progress = total == 0 ? 0.0 : (_position.inMilliseconds / total).clamp(0.0, 1.0);
    final remaining = _playing || _position > Duration.zero
        ? fmtDuration((total - _position.inMilliseconds).clamp(0, total))
        : fmtDuration(total);

    return SizedBox(
      width: 200,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          onTap: _toggle,
          customBorder: const CircleBorder(),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: mine ? const Color(0xFF1E2A3A).withValues(alpha: 0.10) : HomiesColors.accentSoft, shape: BoxShape.circle),
            child: Icon(_playing ? Icons.pause : Icons.play_arrow, color: fg, size: 22),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: track,
                valueColor: AlwaysStoppedAnimation(fill),
              ),
            ),
            const SizedBox(height: 5),
            Row(children: [
              Icon(Icons.mic, size: 12, color: fg.withValues(alpha: 0.7)),
              const SizedBox(width: 3),
              Text(remaining, style: TextStyle(color: fg.withValues(alpha: 0.85), fontSize: 11)),
            ]),
          ]),
        ),
      ]),
    );
  }
}
