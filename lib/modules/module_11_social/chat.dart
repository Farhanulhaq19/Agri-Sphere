import 'dart:async';
import 'package:agrisphere/core/services/realtime.dart';
import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

/// Unread chat count for badges (refreshed when the chat list or dashboard loads).
class ChatBadge {
  static final ValueNotifier<int> unread = ValueNotifier<int>(0);
  static bool _listening = false;

  /// Bump the badge as soon as a message from someone else arrives.
  static void listen(String? myId) {
    if (_listening) return;
    _listening = true;
    Realtime.messages.listen((d) {
      final from = '${(d['message'] as Map?)?['from']}';
      if (myId != null && from != myId) unread.value = unread.value + 1;
    });
  }
  static Future<void> refresh() async {
    try {
      unread.value = toNum(((await AgriApi.get('/chats/unread')) as Map)['count']).round();
    } catch (_) {}
  }
}

/// Opens (or reuses) a chat with the seller / owner of an item.
Future<void> openChat(
  BuildContext context, {
  required String to,
  required String toName,
  String kind = '',
  String refId = '',
  String title = '',
}) async {
  try {
    final c = await AgriApi.post('/chats/start', {'to': to, 'toName': toName, 'kind': kind, 'refId': refId, 'title': title}) as Map;
    if (!context.mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: '${c['id']}', title: toName, topic: title)));
  } catch (e) {
    if (context.mounted) snack(context, cleanErr(e), error: true);
  }
}

/// "Chat" button for detail pages.
class ChatWithButton extends StatelessWidget {
  final String to;
  final String toName;
  final String kind;
  final String refId;
  final String title;
  final String label;
  const ChatWithButton({
    super.key,
    required this.to,
    required this.toName,
    this.kind = '',
    this.refId = '',
    this.title = '',
    this.label = 'Chat',
  });
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: () => openChat(context, to: to, toName: toName, kind: kind, refId: refId, title: title),
        icon: const Icon(Icons.chat_bubble_outline, size: 18),
        label: Text(tr(label)),
        style: OutlinedButton.styleFrom(foregroundColor: C.green, side: const BorderSide(color: C.green)),
      );
}

String _ago(dynamic iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  if (d == null) return '';
  final m = DateTime.now().difference(d).inMinutes;
  if (m < 1) return tr('now');
  if (m < 60) return '${m}m';
  if (m < 1440) return '${m ~/ 60}h';
  return fmtDate(d);
}

/// All my chats.
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});
  @override
  Widget build(BuildContext context) => ListPage(
        title: tr('Messages'),
        subtitle: tr('Chats with buyers, sellers and owners'),
        load: () async {
          final r = await AgriApi.get('/chats');
          ChatBadge.refresh();
          return r;
        },
        empty: 'No messages yet.\nTap "Chat" on a product, machine or warehouse to ask the seller.',
        emptyIcon: Icons.forum_outlined,
        item: (ctx, c, reload) {
          final unread = toNum(c['unread']).round();
          final topic = (c['topic'] as Map?) ?? const {};
          final name = '${c['otherName'] ?? 'User'}';
          return AppCard(
            onTap: () async {
              await Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => ChatScreen(chatId: '${c['id']}', title: name, topic: '${topic['title'] ?? ''}')));
              reload();
            },
            child: Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: C.light,
                child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: const TextStyle(color: C.green, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text(_ago(c['lastAt']), style: const TextStyle(fontSize: 11, color: C.grey)),
                  ]),
                  if ('${topic['title'] ?? ''}'.isNotEmpty)
                    Text('${tr('About')}: ${topic['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: C.green)),
                  Text('${c['lastText'] ?? tr('Say hello 👋')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: unread > 0 ? C.text : C.grey, fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w400)),
                ]),
              ),
              if (unread > 0) ...[
                const SizedBox(width: 8),
                CircleAvatar(radius: 11, backgroundColor: C.green, child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11))),
              ],
            ]),
          );
        },
      );
}

/// One conversation. New messages are fetched every few seconds.
class ChatScreen extends StatefulWidget {
  final String chatId;
  final String title;
  final String topic;
  const ChatScreen({super.key, required this.chatId, required this.title, this.topic = ''});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msg = TextEditingController();
  final _scroll = ScrollController();
  final List<Map> _items = [];
  String? _me;
  String? _err;
  bool _loading = true;
  bool _sending = false;
  Timer? _poll;
  StreamSubscription<Map>? _live;

  static const _quick = ['Is this still available?', 'What is your best price?', 'Can you deliver to my area?', 'When can I pick it up?'];

  @override
  void initState() {
    super.initState();
    AgriApi.get('/me').then((d) {
      if (mounted) setState(() => _me = '${(d as Map)['id']}');
    }).catchError((_) {});
    _load();
    // messages arrive live over the socket; polling is only a slow safety net
    Realtime.connect();
    _live = Realtime.messages.listen((d) {
      if ('${d['chatId']}' != widget.chatId || !mounted) return;
      final m = Map<String, dynamic>.from(d['message'] as Map);
      if (_items.any((e) => '${e['id']}' == '${m['id']}')) return;
      setState(() => _items.add(m));
      _toBottom();
    });
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _live?.cancel();
    _msg.dispose();
    _scroll.dispose();
    ChatBadge.refresh();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final after = _items.isEmpty ? '' : '?after=${Uri.encodeQueryComponent('${_items.last['createdAt']}')}';
      final r = await AgriApi.get('/chats/${widget.chatId}/messages$after') as Map;
      final fresh = ((r['items'] as List?) ?? []).cast<Map>();
      if (!mounted) return;
      final known = _items.map((e) => '${e['id']}').toSet();
      final add = fresh.where((e) => !known.contains('${e['id']}')).toList();
      setState(() {
        _items.addAll(add);
        _loading = false;
        _err = null;
      });
      if (add.isNotEmpty) _toBottom();
    } catch (e) {
      if (mounted && !silent) setState(() {
        _loading = false;
        _err = cleanErr(e);
      });
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  Future<void> _send([String? preset]) async {
    final t = (preset ?? _msg.text).trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final m = await AgriApi.post('/chats/${widget.chatId}/messages', {'text': t}) as Map;
      _msg.clear();
      if (mounted && !_items.any((e) => '${e['id']}' == '${m['id']}')) setState(() => _items.add(m));
      _toBottom();
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
    if (mounted) setState(() => _sending = false);
  }

  Widget _bubble(Map m) {
    final mine = _me != null && '${m['from']}' == _me;
    final at = DateTime.tryParse('${m['createdAt']}')?.toLocal();
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? C.green : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine ? null : Border.all(color: C.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${m['text']}', style: TextStyle(color: mine ? Colors.white : C.text, fontSize: 14)),
          if (at != null)
            Text('${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : C.grey)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.green,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: Colors.white,
            child: Text(widget.title.isEmpty ? '?' : widget.title[0].toUpperCase(), style: const TextStyle(color: C.green, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              if (widget.topic.isNotEmpty)
                Text(widget.topic, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ]),
          ),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: C.green))
              : _err != null && _items.isEmpty
                  ? EmptyState(icon: Icons.cloud_off, text: _err!)
                  : _items.isEmpty
                      ? EmptyState(icon: Icons.waving_hand_outlined, text: tr('Start the conversation. Tap a quick question below or type your own.'))
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(12),
                          itemCount: _items.length,
                          itemBuilder: (_, i) => _bubble(_items[i]),
                        ),
        ),
        if (_items.length < 2)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _quick
                  .map((q) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(label: Text(tr(q)), onPressed: () => _send(tr(q)), backgroundColor: Colors.white),
                      ))
                  .toList(),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _msg,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: tr('Type a message'),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: C.line)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 23,
                backgroundColor: C.green,
                child: IconButton(
                  onPressed: _sending ? null : () => _send(),
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send, color: Colors.white),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
