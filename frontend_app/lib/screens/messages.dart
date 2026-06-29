import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/media.dart';
import '../widgets/avatar.dart';
import '../widgets/chat_media_bubbles.dart';
import '../widgets/ui_kit.dart';

String _dmKey(String a, String b) {
  final ids = [a, b]..sort();
  return ids.join('-');
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String _activeId = 'group';
  final _draftCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Voice recording.
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  bool _busy = false;
  Duration _recordElapsed = Duration.zero;
  DateTime? _recordStartedAt;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _draftCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _draftCtrl.dispose();
    _scrollCtrl.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  List<Message> _messages(HomiesState state) {
    if (_activeId == 'group') return state.messages.group;
    final cu = state.currentUser!;
    return state.messages.dms[_dmKey(cu.id, _activeId)] ?? [];
  }

  void _appendMessage(HomiesState state, Message msg) {
    final cu = state.currentUser!;
    state.mutate(() {
      if (_activeId == 'group') {
        state.messages.group.add(msg);
      } else {
        final key = _dmKey(cu.id, _activeId);
        state.messages.dms.putIfAbsent(key, () => []).add(msg);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    });
  }

  void _send(HomiesState state) {
    final text = _draftCtrl.text.trim();
    if (text.isEmpty) return;
    final cu = state.currentUser!;
    _appendMessage(state, Message(
      id: 'm-${Random().nextInt(0xFFFF).toRadixString(36)}',
      from: cu.id,
      text: text,
      at: DateTime.now().toIso8601String(),
    ));
    _draftCtrl.clear();
  }

  void _sendMedia(HomiesState state, String type, Attachment media) {
    final cu = state.currentUser!;
    _appendMessage(state, Message(
      id: 'm-${Random().nextInt(0xFFFF).toRadixString(36)}',
      from: cu.id,
      text: '',
      at: DateTime.now().toIso8601String(),
      type: type,
      media: media,
    ));
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- Photo / video attachments -------------------------------------------

  Future<void> _openAttachSheet(HomiesState state) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Align(alignment: Alignment.centerLeft, child: Text('Share', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
          ),
          _attachTile(Icons.photo_camera_outlined, 'Take photo', 'camera-photo'),
          _attachTile(Icons.photo_library_outlined, 'Photo from gallery', 'gallery-photo'),
          _attachTile(Icons.videocam_outlined, 'Record video', 'camera-video'),
          _attachTile(Icons.video_library_outlined, 'Video from gallery', 'gallery-video'),
          _attachTile(Icons.poll_outlined, 'Create a poll', 'poll'),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'camera-photo':
        await _attachImage(state, fromCamera: true);
        break;
      case 'gallery-photo':
        await _attachImage(state, fromCamera: false);
        break;
      case 'camera-video':
        await _attachVideo(state, fromCamera: true);
        break;
      case 'gallery-video':
        await _attachVideo(state, fromCamera: false);
        break;
      case 'poll':
        await _openPollComposer(state);
        break;
    }
  }

  Widget _attachTile(IconData icon, String label, String value) => ListTile(
        leading: Icon(icon, color: HomiesColors.accent),
        title: Text(label),
        onTap: () => Navigator.pop(context, value),
      );

  Future<void> _attachImage(HomiesState state, {required bool fromCamera}) async {
    final res = await pickImageAttachment(fromCamera: fromCamera);
    if (res.cancelled) return;
    if (res.error != null) {
      _toast(res.error!);
      return;
    }
    _sendMedia(state, 'image', res.attachment!);
  }

  Future<void> _attachVideo(HomiesState state, {required bool fromCamera}) async {
    final res = await pickVideoAttachment(fromCamera: fromCamera);
    if (res.cancelled) return;
    if (res.error != null) {
      _toast(res.error!);
      return;
    }
    _sendMedia(state, 'video', res.attachment!);
  }

  // --- Voice recording ------------------------------------------------------

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        _toast('Microphone permission is needed for voice messages.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      _recordStartedAt = DateTime.now();
      _recordElapsed = Duration.zero;
      _recordTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted || _recordStartedAt == null) return;
        setState(() => _recordElapsed = DateTime.now().difference(_recordStartedAt!));
      });
      setState(() => _recording = true);
    } catch (_) {
      _toast("Couldn't start recording.");
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {/* ignore */}
    if (mounted) setState(() => _recording = false);
  }

  Future<void> _stopAndSendRecording(HomiesState state) async {
    _recordTimer?.cancel();
    final elapsed = _recordElapsed;
    setState(() {
      _recording = false;
      _busy = true;
    });
    try {
      final path = await _recorder.stop();
      if (path == null) {
        _toast("Recording failed.");
        return;
      }
      if (elapsed.inMilliseconds < 800) {
        _toast('Too short — hold a little longer.');
        return;
      }
      final res = await voiceFileToAttachment(path, elapsed.inMilliseconds);
      if (res.error != null) {
        _toast(res.error!);
        return;
      }
      if (res.attachment != null) _sendMedia(state, 'voice', res.attachment!);
    } catch (_) {
      _toast("Couldn't save that recording.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPollComposer(HomiesState state) async {
    final cu = state.currentUser!;
    final result = await showModalBottomSheet<_PollDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: const _NewPollModal(),
      ),
    );
    if (result == null) return;
    _appendMessage(state, Message(
      id: 'm-${Random().nextInt(0xFFFF).toRadixString(36)}',
      from: cu.id,
      text: '',
      at: DateTime.now().toIso8601String(),
      type: 'poll',
      poll: MessagePoll(
        question: result.question,
        multi: result.multi,
        options: [
          for (final t in result.options)
            PollOption(id: 'o-${Random().nextInt(0xFFFF).toRadixString(36)}', text: t, addedBy: cu.id),
        ],
        votes: {},
      ),
    ));
  }

  void _togglePollVote(HomiesState state, Message msg, String optionId) {
    final cu = state.currentUser!;
    final poll = msg.poll;
    if (poll == null || poll.closed) return;
    state.mutate(() {
      final votes = poll.votes;
      final alreadyVoted = (votes[optionId] ?? const []).contains(cu.id);
      if (poll.multi) {
        final current = List<String>.from(votes[optionId] ?? const []);
        if (alreadyVoted) {
          current.remove(cu.id);
        } else {
          current.add(cu.id);
        }
        votes[optionId] = current;
      } else {
        for (final o in poll.options) {
          final list = List<String>.from(votes[o.id] ?? const []);
          list.remove(cu.id);
          votes[o.id] = list;
        }
        if (!alreadyVoted) {
          votes[optionId] = [...votes[optionId] ?? const [], cu.id];
        }
      }
    });
  }

  void _addPollOption(HomiesState state, Message msg, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final cu = state.currentUser!;
    final poll = msg.poll;
    if (poll == null || poll.closed) return;
    state.mutate(() {
      poll.options.add(PollOption(
        id: 'o-${Random().nextInt(0xFFFF).toRadixString(36)}',
        text: trimmed,
        addedBy: cu.id,
      ));
    });
  }

  void _closePoll(HomiesState state, Message msg) {
    final poll = msg.poll;
    if (poll == null) return;
    state.mutate(() => poll.closed = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final others = state.activeHousemates.where((u) => u.id != cu.id).toList();
    final messages = _messages(state);
    final isGroup = _activeId == 'group';

    return SafeArea(
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 700;
        return wide
            ? Row(children: [
                SizedBox(width: 240, child: _convList(state, others)),
                const VerticalDivider(width: 1),
                Expanded(child: _chatColumn(state, messages, isGroup, cu, others)),
              ])
            : Column(children: [
                SizedBox(
                  height: 86,
                  child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), children: [
                    _convPill(name: 'House', active: isGroup, onTap: () => setState(() => _activeId = 'group')),
                    for (final u in others)
                      _convPill(name: u.name.split(' ').first, active: _activeId == u.id, onTap: () => setState(() => _activeId = u.id), avatar: u),
                  ]),
                ),
                const Divider(height: 1),
                Expanded(child: _chatColumn(state, messages, isGroup, cu, others)),
              ]);
      }),
    );
  }

  Widget _convList(HomiesState state, List<User> others) {
    return ListView(children: [
      ListTile(
        title: const Text('House group', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${state.activeHousemates.length} members'),
        selected: _activeId == 'group',
        selectedTileColor: HomiesColors.accentSoft,
        onTap: () => setState(() => _activeId = 'group'),
      ),
      for (final u in others)
        ListTile(
          leading: Avatar(user: u),
          title: Text(u.name),
          subtitle: Text(u.role),
          selected: _activeId == u.id,
          selectedTileColor: HomiesColors.accentSoft,
          onTap: () => setState(() => _activeId = u.id),
        ),
    ]);
  }

  Widget _convPill({required String name, required bool active, required VoidCallback onTap, User? avatar}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 70,
          decoration: BoxDecoration(
            color: active ? HomiesColors.accentSoft : HomiesColors.surface,
            border: Border.all(color: active ? HomiesColors.accent : HomiesColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            avatar != null ? Avatar(user: avatar, size: 30) : const Icon(Icons.group, size: 30, color: HomiesColors.accent),
            const SizedBox(height: 4),
            Text(name, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 1),
          ]),
        ),
      ),
    );
  }

  bool _isQuietHours(String start, String end) {
    final now = DateTime.now();
    final sp = start.split(':');
    final ep = end.split(':');
    final sMin = int.parse(sp[0]) * 60 + int.parse(sp[1]);
    final eMin = int.parse(ep[0]) * 60 + int.parse(ep[1]);
    final nMin = now.hour * 60 + now.minute;
    return sMin > eMin ? (nMin >= sMin || nMin < eMin) : (nMin >= sMin && nMin < eMin);
  }

  void _togglePin(HomiesState state, Message m) {
    state.mutate(() => m.pinned = !m.pinned);
  }

  Widget _chatColumn(HomiesState state, List<Message> messages, bool isGroup, User cu, List<User> others) {
    final activeUser = isGroup ? null : others.firstWhere((u) => u.id == _activeId, orElse: () => cu);
    final isLeaseholder = cu.role == 'leaseholder';
    final terms = state.houseTerms;
    final quietActive = isGroup && _isQuietHours(terms.quietHoursStart, terms.quietHoursEnd);
    final pinnedMsgs = isGroup ? messages.where((m) => m.pinned && m.type == 'text').toList() : <Message>[];

    return Column(children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: HomiesColors.border))),
        child: Row(children: [
          if (isGroup)
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(color: HomiesColors.accentSoft, shape: BoxShape.circle),
              child: const Icon(Icons.group, color: HomiesColors.accent, size: 20),
            )
          else
            Avatar(user: activeUser),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isGroup ? 'House group' : activeUser?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
              Row(children: [
                Text(isGroup ? '${state.activeHousemates.length} living here' : 'Just the two of you',
                    style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                if (isGroup) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: quietActive ? const Color(0xFFFFF3CD) : HomiesColors.surface2,
                      border: Border.all(color: quietActive ? const Color(0xFFE0A000) : HomiesColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.bedtime_outlined, size: 10,
                          color: quietActive ? const Color(0xFFB07000) : HomiesColors.textFaint),
                      const SizedBox(width: 3),
                      Text(
                        quietActive
                            ? 'Quiet hours'
                            : '${terms.quietHoursStart}–${terms.quietHoursEnd}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: quietActive ? const Color(0xFFB07000) : HomiesColors.textFaint,
                        ),
                      ),
                    ]),
                  ),
                ],
              ]),
            ]),
          ),
        ]),
      ),
      if (pinnedMsgs.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF5F0FF),
            border: Border(bottom: BorderSide(color: Color(0xFFD0B8F0))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.push_pin_rounded, size: 13, color: Color(0xFF7C4DCC)),
                SizedBox(width: 4),
                Text('Pinned', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF7C4DCC))),
              ]),
              const SizedBox(height: 4),
              for (final m in pinnedMsgs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        m.text,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF3D2070)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isLeaseholder)
                      GestureDetector(
                        onTap: () => _togglePin(state, m),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.close, size: 14, color: Color(0xFF9E6DCC)),
                        ),
                      ),
                  ]),
                ),
            ],
          ),
        ),
      Expanded(
        child: messages.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.forum_outlined, size: 40, color: HomiesColors.textFaint),
                  const SizedBox(height: 8),
                  const Text('No messages yet — say hi 👋', style: TextStyle(color: HomiesColors.textDim)),
                ]),
              )
            : ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final m = messages[i];
                  final prev = i > 0 ? messages[i - 1] : null;
                  final showDay = prev == null || fmtChatDay(prev.at) != fmtChatDay(m.at);
                  return Column(children: [
                    if (showDay) _dayDivider(fmtChatDay(m.at)),
                    _messageRow(state, m, cu, canPin: isGroup && isLeaseholder && m.type == 'text'),
                  ]);
                },
              ),
      ),
      _composer(state),
    ]);
  }

  Widget _dayDivider(String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: HomiesColors.surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: HomiesColors.border)),
            child: Text(label, style: const TextStyle(fontSize: 11, color: HomiesColors.textDim, fontWeight: FontWeight.w600)),
          ),
        ),
      );

  Widget _messageRow(HomiesState state, Message m, User cu, {bool canPin = false}) {
    final mine = m.from == cu.id;
    final sender = state.findUser(m.from);
    final isMedia = m.type == 'image' || m.type == 'video' || m.type == 'voice';
    final isPoll = m.type == 'poll' && m.poll != null;

    Widget bubble;
    if (isPoll) {
      bubble = _PollBubble(
        message: m,
        mine: mine,
        senderName: sender?.name,
        currentUserId: cu.id,
        onVote: (optId) => _togglePollVote(state, m, optId),
        onAddOption: (text) => _addPollOption(state, m, text),
        onClose: () => _closePoll(state, m),
      );
    } else {
      // Media bubbles get a tighter, transparent-ish container; text keeps the
      // classic coloured bubble.
      final media = m.media;
      Widget content;
      if (m.type == 'image' && media != null) {
        content = ChatImageBubble(media: media, caption: m.text, mine: mine);
      } else if (m.type == 'video' && media != null) {
        content = ChatVideoBubble(media: media, caption: m.text, mine: mine);
      } else if (m.type == 'voice' && media != null) {
        content = ChatVoiceBubble(media: media, mine: mine);
      } else {
        content = Text(m.text, style: TextStyle(color: mine ? const Color(0xFF1E2A3A) : HomiesColors.text, fontSize: 14));
      }
      bubble = Container(
        padding: m.type == 'image' || m.type == 'video'
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          gradient: mine
              ? const LinearGradient(
                  colors: [Color(0xFFB3D5FF), Color(0xFFFFB3DA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: mine ? null : HomiesColors.surface2,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine ? null : Border.all(color: HomiesColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (!mine && !isMedia)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(sender?.name.split(' ').first ?? '—',
                  style: const TextStyle(fontSize: 11, color: HomiesColors.accentStrong, fontWeight: FontWeight.w600)),
            ),
          content,
          const SizedBox(height: 3),
          Text(fmtTime(m.at),
              style: TextStyle(fontSize: 10, color: mine ? const Color(0xFF4A5E78) : HomiesColors.textFaint)),
        ]),
      );
    }

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) Avatar.sm(sender),
          if (!mine) const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            child: bubble,
          ),
          if (m.pinned) ...[
            const SizedBox(width: 4),
            const Icon(Icons.push_pin_rounded, size: 12, color: Color(0xFF9E6DCC)),
          ],
        ],
      ),
    );

    if (!canPin) return row;
    return GestureDetector(
      onLongPress: () => showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: Icon(
                m.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                color: const Color(0xFF7C4DCC),
              ),
              title: Text(m.pinned ? 'Unpin message' : 'Pin message'),
              onTap: () {
                _togglePin(state, m);
                Navigator.pop(context);
              },
            ),
          ]),
        ),
      ),
      child: row,
    );
  }

  Widget _composer(HomiesState state) {
    if (_recording) return _recordingBar(state);
    final hasText = _draftCtrl.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 8, 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: HomiesColors.border))),
      child: SafeArea(
        top: false,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          IconButton(
            tooltip: 'Share photo, video or poll',
            icon: const Icon(Icons.add_circle_outline, color: HomiesColors.accent),
            onPressed: _busy ? null : () => _openAttachSheet(state),
          ),
          Expanded(
            child: TextField(
              controller: _draftCtrl,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Message…',
                isDense: true,
                filled: true,
                fillColor: HomiesColors.surface2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: HomiesColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: HomiesColors.accent, width: 1.5)),
              ),
              onSubmitted: (_) => _send(state),
            ),
          ),
          const SizedBox(width: 6),
          hasText
              ? _circleButton(Icons.send_rounded, () => _send(state))
              : _circleButton(Icons.mic, _busy ? null : _startRecording),
        ]),
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback? onTap) => Material(
        color: onTap == null ? HomiesColors.textFaint : HomiesColors.accent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, color: Colors.white, size: 22)),
        ),
      );

  Widget _recordingBar(HomiesState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: HomiesColors.border))),
      child: SafeArea(
        top: false,
        child: Row(children: [
          IconButton(
            tooltip: 'Cancel',
            icon: const Icon(Icons.delete_outline, color: HomiesColors.danger),
            onPressed: _cancelRecording,
          ),
          const _RecordingDot(),
          const SizedBox(width: 8),
          Text(fmtDuration(_recordElapsed.inMilliseconds),
              style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
          const Spacer(),
          const Text('Recording…', style: TextStyle(color: HomiesColors.textDim, fontSize: 13)),
          const SizedBox(width: 8),
          _circleButton(Icons.send_rounded, () => _stopAndSendRecording(state)),
        ]),
      ),
    );
  }
}

/// A small pulsing red dot shown while recording a voice message.
class _RecordingDot extends StatefulWidget {
  const _RecordingDot();
  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
      child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: HomiesColors.danger, shape: BoxShape.circle)),
    );
  }
}

class _PollBubble extends StatefulWidget {
  final Message message;
  final bool mine;
  final String? senderName;
  final String currentUserId;
  final ValueChanged<String> onVote;
  final ValueChanged<String> onAddOption;
  final VoidCallback onClose;
  const _PollBubble({
    required this.message,
    required this.mine,
    required this.senderName,
    required this.currentUserId,
    required this.onVote,
    required this.onAddOption,
    required this.onClose,
  });

  @override
  State<_PollBubble> createState() => _PollBubbleState();
}

class _PollBubbleState extends State<_PollBubble> {
  final _newOptionCtrl = TextEditingController();

  @override
  void dispose() {
    _newOptionCtrl.dispose();
    super.dispose();
  }

  void _submitOption() {
    final text = _newOptionCtrl.text.trim();
    if (text.isEmpty) return;
    widget.onAddOption(text);
    _newOptionCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.message.poll!;
    final mine = widget.mine;
    final isCreator = widget.message.from == widget.currentUserId;
    final totalVotes = poll.votes.values.fold<int>(0, (sum, v) => sum + v.length);
    final fg = mine ? const Color(0xFF1E2A3A) : HomiesColors.text;
    final subFg = mine ? const Color(0xFF4A5E78) : HomiesColors.textDim;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: mine
            ? const LinearGradient(
                colors: [Color(0xFFB3D5FF), Color(0xFFFFB3DA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: mine ? null : HomiesColors.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (!mine && widget.senderName != null)
          Text(widget.senderName!,
              style: const TextStyle(fontSize: 11, color: HomiesColors.textDim, fontWeight: FontWeight.w600)),
        Text('📊 ${poll.question}',
            style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          [
            poll.multi ? 'Multiple choice' : 'Single choice',
            if (poll.closed) 'closed',
            if (totalVotes > 0) '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
          ].join(' · '),
          style: TextStyle(color: subFg, fontSize: 11),
        ),
        const SizedBox(height: 8),
        for (final opt in poll.options)
          _PollOptionRow(
            option: opt,
            voters: poll.votes[opt.id] ?? const [],
            totalVotes: totalVotes,
            voted: (poll.votes[opt.id] ?? const []).contains(widget.currentUserId),
            mine: mine,
            disabled: poll.closed,
            onTap: () => widget.onVote(opt.id),
          ),
        if (!poll.closed) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _newOptionCtrl,
                style: TextStyle(color: fg, fontSize: 13),
                decoration: InputDecoration(
                  hintText: '+ Add option',
                  hintStyle: TextStyle(color: subFg, fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: mine ? const Color(0xFF4A5E78).withValues(alpha: 0.35) : HomiesColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: mine ? const Color(0xFF4A5E78).withValues(alpha: 0.35) : HomiesColors.border),
                  ),
                ),
                onSubmitted: (_) => _submitOption(),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: _newOptionCtrl.text.trim().isEmpty ? null : _submitOption,
              child: Text('Add', style: TextStyle(color: mine ? const Color(0xFF1E2A3A) : HomiesColors.accent)),
            ),
          ]),
        ],
        if (isCreator && !poll.closed)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onClose,
              child: Text('Close poll', style: TextStyle(color: subFg, fontSize: 12)),
            ),
          ),
      ]),
    );
  }
}

class _PollOptionRow extends StatelessWidget {
  final PollOption option;
  final List<String> voters;
  final int totalVotes;
  final bool voted;
  final bool mine;
  final bool disabled;
  final VoidCallback onTap;
  const _PollOptionRow({
    required this.option,
    required this.voters,
    required this.totalVotes,
    required this.voted,
    required this.mine,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalVotes > 0 ? (voters.length / totalVotes) : 0.0;
    final fg = mine ? const Color(0xFF1E2A3A) : HomiesColors.text;
    final borderColor = mine ? const Color(0xFF4A5E78).withValues(alpha: 0.35) : HomiesColors.borderStrong;
    final fillColor = mine ? const Color(0xFF1E2A3A).withValues(alpha: 0.12) : HomiesColors.accentSoft;
    final bgColor = mine ? const Color(0xFF1E2A3A).withValues(alpha: 0.05) : HomiesColors.surface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Stack(children: [
            Container(
              decoration: BoxDecoration(
                color: bgColor,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(10),
              ),
              child: LayoutBuilder(builder: (context, c) {
                return Stack(children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: FractionallySizedBox(
                      heightFactor: 1,
                      widthFactor: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: c.maxWidth * pct,
                          child: ColoredBox(color: fillColor),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          '${voted ? '✓ ' : ''}${option.text}',
                          style: TextStyle(color: fg, fontSize: 13, fontWeight: voted ? FontWeight.w600 : FontWeight.normal),
                        ),
                      ),
                      Text('${voters.length} · ${(pct * 100).round()}%',
                          style: TextStyle(color: fg.withValues(alpha: 0.85), fontSize: 11)),
                    ]),
                  ),
                ]);
              }),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PollDraft {
  final String question;
  final List<String> options;
  final bool multi;
  const _PollDraft({required this.question, required this.options, required this.multi});
}

class _NewPollModal extends StatefulWidget {
  const _NewPollModal();
  @override
  State<_NewPollModal> createState() => _NewPollModalState();
}

class _NewPollModalState extends State<_NewPollModal> {
  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [TextEditingController(), TextEditingController()];
  bool _multi = false;

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() => _optionCtrls.add(TextEditingController()));
  }

  void _removeOption(int i) {
    setState(() {
      _optionCtrls.removeAt(i).dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final trimmedOptions = _optionCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    final canCreate = _questionCtrl.text.trim().isNotEmpty && trimmedOptions.length >= 2;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('New poll', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('Anyone in this chat can vote and add more options.',
                  style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
              const SizedBox(height: 12),
              const FieldLabel('Question'),
              TextField(
                controller: _questionCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Pizza or Thai tonight?'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              const FieldLabel('Options'),
              for (var i = 0; i < _optionCtrls.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _optionCtrls[i],
                        decoration: InputDecoration(hintText: 'Option ${i + 1}'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_optionCtrls.length > 2)
                      IconButton(icon: const Icon(Icons.close), onPressed: () => _removeOption(i)),
                  ]),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add option'),
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                value: _multi,
                onChanged: (v) => setState(() => _multi = v),
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow multiple votes per person', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: canCreate
                      ? () => Navigator.pop(
                            context,
                            _PollDraft(
                              question: _questionCtrl.text.trim(),
                              options: trimmedOptions,
                              multi: _multi,
                            ),
                          )
                      : null,
                  child: const Text('Send poll'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
