import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/voice.dart';
import 'package:agrisphere/modules/module_06_expert/screens/ask_expert_screen.dart';
import 'package:agrisphere/modules/module_12_ai/crop_doctor_screen.dart';

/// AgriChatBot: an AI farming assistant that answers any time, in English or Urdu.
class AgriChatBotScreen extends StatefulWidget {
  final String? firstQuestion;
  /// who is asking: farmer | buyer | supplier | machinery | warehouse | expert | admin (changes suggestions + answers)
  final String role;
  const AgriChatBotScreen({super.key, this.firstQuestion, this.role = 'farmer'});
  @override
  State<AgriChatBotScreen> createState() => _AgriChatBotScreenState();
}

class _AgriChatBotScreenState extends State<AgriChatBotScreen> {
  final _msg = TextEditingController();
  final _scroll = ScrollController();
  final List<Map> _items = [];
  bool _loading = true;
  bool _thinking = false;
  String _provider = '';
  String? _err;

  static const _startersByRole = {
    'farmer': [
      ('🌾', 'My wheat leaves have yellow stripes. What should I do?'),
      ('💧', 'How often should I irrigate wheat in December?'),
      ('🐛', 'How do I control whitefly on cotton?'),
      ('🧪', 'How much DAP and urea per acre for maize?'),
      ('🥔', 'Best time to sow potatoes in Punjab?'),
      ('💰', 'How do I sell my crop on AgriSphere?'),
    ],
    'buyer': [
      ('🛒', 'How do I check wheat quality before buying?'),
      ('📦', 'What is the best way to store onions after buying?'),
      ('💳', 'How do I pay with Easypaisa on AgriSphere?'),
      ('🤝', 'How should I negotiate a fair price with a farmer?'),
      ('🚚', 'How does delivery and order tracking work?'),
    ],
    'supplier': [
      ('🧪', 'Which fertilizers do farmers need for wheat sowing season?'),
      ('📈', 'When is the peak season for selling maize seed?'),
      ('🏷️', 'How should I price DAP and urea bags competitively?'),
      ('📸', 'How do I write a good product listing that sells?'),
      ('🛡️', 'What safety advice should I give when selling pesticides?'),
    ],
    'machinery': [
      ('🚜', 'How often should a tractor get an oil change and service?'),
      ('🌾', 'When is harvester demand highest in Punjab?'),
      ('💰', 'What is a fair hourly rent for a 85 HP tractor?'),
      ('🔧', 'How do I keep a combine harvester ready for wheat season?'),
      ('👷', 'Tips for training my tractor operators safely'),
    ],
    'warehouse': [
      ('❄️', 'What temperature and humidity are best for storing potatoes?'),
      ('🐀', 'How do I protect stored wheat from insects and rats?'),
      ('🌡️', 'Why is condensation forming in my cold store and how to fix it?'),
      ('💨', 'How and when should I fumigate a grain store safely?'),
      ('📊', 'How do I set a fair storage rate per ton per day?'),
    ],
    'expert': [
      ('🔬', 'Differences between yellow rust and brown rust in wheat'),
      ('🧫', 'Latest IPM approach for pink bollworm in cotton'),
      ('🌱', 'Recommended rust-resistant wheat varieties for Punjab'),
      ('💧', 'Signs of zinc deficiency in rice and the treatment'),
      ('📝', 'How should I explain fungicide safety to farmers simply?'),
    ],
    'admin': [
      ('📊', 'How can I verify an Easypaisa payment screenshot is real?'),
      ('🛡️', 'What signs show a fake or scam listing?'),
      ('📣', 'Ideas to get more farmers to join AgriSphere'),
      ('⭐', 'How should I handle a complaint between a buyer and seller?'),
    ],
  };
  List<(String, String)> get _starters => _startersByRole[widget.role] ?? _startersByRole['farmer']!;

  static const _intro = {
    'farmer': 'Ask me anything about crops, pests, fertilizer, weather or selling. I answer in seconds, day or night, in English or Urdu.',
    'buyer': 'Ask me about produce quality, storage, fair prices, payments or delivery. I answer in seconds, any time.',
    'supplier': 'Ask me about seasonal demand, fertilizer and seed advice, pricing or writing listings that sell.',
    'machinery': 'Ask me about machine maintenance, seasonal demand, fair rent rates or running your fleet.',
    'warehouse': 'Ask me about safe storage, temperature and humidity, pests, fumigation or storage rates.',
    'expert': 'Ask me for quick technical references on diseases, pests, varieties and treatments.',
    'admin': 'Ask me about verifying payments, spotting fake listings or growing the platform.',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msg.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await AgriApi.get('/ai/chat') as Map;
      _items
        ..clear()
        ..addAll(((r['items'] as List?) ?? const []).cast<Map>());
      _provider = '${r['provider'] ?? ''}';
    } catch (e) {
      _err = cleanErr(e);
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _toBottom();
    final q = widget.firstQuestion;
    if (q != null && q.isNotEmpty) _send(q);
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      });

  Future<void> _send([String? preset]) async {
    final t = (preset ?? _msg.text).trim();
    if (t.isEmpty || _thinking) return;
    _msg.clear();
    setState(() {
      _items.add({'role': 'user', 'content': t, 'at': DateTime.now().toIso8601String()});
      _thinking = true;
    });
    _toBottom();
    try {
      final r = await AgriApi.post('/ai/chat', {'text': t, 'lang': AppLang.isUrdu ? 'ur' : 'en', 'role': widget.role}) as Map;
      if (!mounted) return;
      setState(() => _items.add({'role': 'assistant', 'content': '${r['reply']}', 'at': '${r['at']}', 'source': '${r['source'] ?? ''}'}));
    } catch (e) {
      if (!mounted) return;
      setState(() => _items.add({'role': 'error', 'content': cleanErr(e), 'retry': t}));
    }
    if (mounted) setState(() => _thinking = false);
    _toBottom();
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Start a new chat?')),
        content: Text(tr('This clears your conversation with AgriChatBot.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Cancel'))),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('Clear'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AgriApi.delete('/ai/chat');
      if (mounted) setState(() => _items.clear());
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
  }

  // very small formatter: **bold** and bullet lines
  Widget _rich(String text, Color color) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((l) {
        final bullet = RegExp(r'^\s*([-*•]|\d+[.)])\s+').firstMatch(l);
        final body = bullet == null ? l : l.substring(bullet.end);
        final spans = <TextSpan>[];
        final parts = body.split('**');
        for (var i = 0; i < parts.length; i++) {
          spans.add(TextSpan(text: parts[i], style: TextStyle(fontWeight: i.isOdd ? FontWeight.w800 : FontWeight.w400)));
        }
        final rich = RichText(text: TextSpan(style: TextStyle(color: color, fontSize: 14, height: 1.4), children: spans));
        if (l.trim().isEmpty) return const SizedBox(height: 6);
        if (bullet == null) return rich;
        return Padding(
          padding: const EdgeInsets.only(left: 4, top: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(RegExp(r'\d').hasMatch(bullet.group(1)!) ? '${bullet.group(1)} ' : '•  ', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            Expanded(child: rich),
          ]),
        );
      }).toList(),
    );
  }

  static const _sources = {
    'ollama': 'Laptop AI (free, offline)',
    'groq': 'Online AI (free)',
    'anthropic': 'Claude AI',
    'offline': 'Built-in farming guide (AI model not running)',
  };
  String _sourceLabel(String s) => _sources[s] == null ? '' : tr(_sources[s]!);

  Widget _bubble(Map m) {
    final role = '${m['role']}';
    if (role == 'error') {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFFEBEB), borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 18),
            const SizedBox(width: 6),
            Flexible(child: Text('${m['content']}', style: const TextStyle(color: Colors.red, fontSize: 12.5))),
            TextButton(
              onPressed: () {
                setState(() => _items.remove(m));
                final last = _items.isNotEmpty && _items.last['role'] == 'user' ? _items.removeLast() : null;
                _send('${last?['content'] ?? m['retry']}');
              },
              child: Text(tr('Retry')),
            ),
          ]),
        ),
      );
    }
    final mine = role == 'user';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (!mine) ...[
          const CircleAvatar(radius: 14, backgroundColor: C.light, child: Text('🌱', style: TextStyle(fontSize: 14))),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: '${m['content']}'));
              snack(context, 'Copied');
            },
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
              decoration: BoxDecoration(
                color: mine ? C.green : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(mine ? 18 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 18),
                ),
                border: mine ? null : Border.all(color: C.line),
              ),
              child: mine
                  ? Text('${m['content']}', style: const TextStyle(color: Colors.white, fontSize: 14))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _rich('${m['content']}', C.text),
                      if (_sourceLabel('${m['source'] ?? ''}').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(_sourceLabel('${m['source']}'), style: const TextStyle(fontSize: 10.5, color: C.grey, fontStyle: FontStyle.italic)),
                        ),
                    ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _welcome() => ListView(padding: const EdgeInsets.all(16), children: [
        const SizedBox(height: 10),
        const Center(child: CircleAvatar(radius: 38, backgroundColor: C.light, child: Text('🌱', style: TextStyle(fontSize: 38)))),
        const SizedBox(height: 10),
        Center(child: Text(tr('Assalam o Alaikum! I am AgriChatBot'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
        const SizedBox(height: 4),
        Center(
          child: Text(tr(_intro[widget.role] ?? _intro['farmer']!),
              textAlign: TextAlign.center, style: const TextStyle(color: C.grey)),
        ),
        if (_provider == 'offline') ...[
          const SizedBox(height: 12),
          AppCard(child: Text(tr('The AI model is not running, so answers come from the built-in farming guide. Start Ollama on the server computer for full AI answers.'), style: const TextStyle(color: Color(0xFFD97706)))),
        ],
        const SizedBox(height: 16),
        Text(tr('Try asking'), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ..._starters.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _send(tr(s.$2)),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
                  child: Row(children: [
                    Text(s.$1, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(tr(s.$2))),
                    const Icon(Icons.north_east, size: 16, color: C.grey),
                  ]),
                ),
              ),
            )),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CropDoctorScreen())),
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(tr('Crop Doctor (photo)')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AskExpertScreen())),
              icon: const Icon(Icons.support_agent),
              label: Text(tr('Ask a human expert')),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Text(tr('AgriChatBot can make mistakes. For serious problems, confirm with an expert.'),
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: C.grey)),
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.bg,
        appBar: AppBar(
          backgroundColor: C.green,
          foregroundColor: Colors.white,
          titleSpacing: 0,
          title: Row(children: [
            const CircleAvatar(radius: 17, backgroundColor: Colors.white, child: Text('🌱')),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('AgriChatBot', style: TextStyle(fontWeight: FontWeight.w800)),
              Text(_thinking ? tr('typing...') : tr('AI farming assistant · always online'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ]),
          ]),
          actions: [
            IconButton(
              tooltip: tr('Crop Doctor (photo)'),
              icon: const Icon(Icons.camera_alt_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CropDoctorScreen())),
            ),
            if (_items.isNotEmpty) IconButton(tooltip: tr('New chat'), icon: const Icon(Icons.refresh), onPressed: _clear),
          ],
        ),
        body: Column(children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: C.green))
                : _err != null && _items.isEmpty
                    ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_err!, textAlign: TextAlign.center)))
                    : _items.isEmpty
                        ? _welcome()
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.all(12),
                            itemCount: _items.length + (_thinking ? 1 : 0),
                            itemBuilder: (_, i) => i == _items.length ? const _Typing() : _bubble(_items[i]),
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
                      hintText: tr('Ask a farming question...'),
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: VoiceSearchButton(onResult: (t) => _msg.text = t),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: C.line)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 23,
                  backgroundColor: _thinking ? C.grey : C.green,
                  child: IconButton(onPressed: _thinking ? null : () => _send(), icon: const Icon(Icons.send, color: Colors.white)),
                ),
              ]),
            ),
          ),
        ]),
      );
}

/// Three bouncing dots while the bot is answering.
class _Typing extends StatefulWidget {
  const _Typing();
  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(left: 34, top: 4, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
          child: AnimatedBuilder(
            animation: _a,
            builder: (_, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = ((_a.value * 3 - i) % 3).clamp(0.0, 1.0);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 7,
                  height: 7,
                  transform: Matrix4.translationValues(0, -4 * (t < 0.5 ? t * 2 : 2 - t * 2), 0),
                  decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle),
                );
              }),
            ),
          ),
        ),
      );
}


/// Floating "Ask AgriChatBot" button for any role's home screen.
class AgriChatBotFab extends StatelessWidget {
  final String role;
  const AgriChatBotFab({super.key, this.role = 'farmer'});
  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        heroTag: 'agrichatbot-$role',
        backgroundColor: C.green,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AgriChatBotScreen(role: role))),
        icon: const Text('🌱', style: TextStyle(fontSize: 18)),
        label: Text(tr('Ask AgriChatBot')),
      );
}

/// Card version for home screens that already use their floating button for something else.
class AgriChatBotCard extends StatelessWidget {
  final String role;
  final String subtitle;
  const AgriChatBotCard({super.key, this.role = 'farmer', this.subtitle = 'AI assistant · answers in seconds, any time'});
  @override
  Widget build(BuildContext context) => AppCard(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AgriChatBotScreen(role: role))),
        child: Row(children: [
          const CircleAvatar(radius: 22, backgroundColor: C.light, child: Text('🌱', style: TextStyle(fontSize: 22))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Ask AgriChatBot'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(tr(subtitle), style: const TextStyle(fontSize: 12, color: C.grey)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: C.green),
        ]),
      );
}
