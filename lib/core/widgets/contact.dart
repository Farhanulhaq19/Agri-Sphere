import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

String _digits(String p) => p.replaceAll(RegExp(r'[^0-9+]'), '');

/// 03001234567 -> 0300 1234567 (easier to read)
String prettyPhone(String p) {
  final d = _digits(p);
  if (RegExp(r'^03\d{9}$').hasMatch(d)) return '${d.substring(0, 4)} ${d.substring(4)}';
  return d;
}

Future<void> callPhone(BuildContext context, String phone) async {
  final ok = await launchUrl(Uri(scheme: 'tel', path: _digits(phone)));
  if (!ok && context.mounted) {
    Clipboard.setData(ClipboardData(text: _digits(phone)));
    snack(context, 'Number copied: ${prettyPhone(phone)}');
  }
}

Future<void> openWhatsApp(BuildContext context, String phone, {String text = ''}) async {
  var d = _digits(phone).replaceFirst('+', '');
  if (d.startsWith('0')) d = '92${d.substring(1)}'; // Pakistan country code
  final u = Uri.parse('https://wa.me/$d${text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}'}');
  if (!await launchUrl(u, mode: LaunchMode.externalApplication) && context.mounted) {
    snack(context, 'WhatsApp is not available', error: true);
  }
}

/// A person's phone with Call and WhatsApp buttons. Shows nothing when there is no number.
class ContactRow extends StatelessWidget {
  final String label;
  final String name;
  final String phone;
  final String whatsappText;
  const ContactRow({super.key, required this.label, required this.name, required this.phone, this.whatsappText = ''});

  @override
  Widget build(BuildContext context) {
    final has = _digits(phone).length >= 10;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: C.light,
          child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: C.green, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(label), style: const TextStyle(fontSize: 11, color: C.grey)),
            Text(tr(name), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(has ? prettyPhone(phone) : tr('No phone number'), style: TextStyle(fontSize: 12.5, color: has ? C.text : C.grey)),
          ]),
        ),
        if (has) ...[
          IconButton.filledTonal(
            tooltip: tr('Call'),
            onPressed: () => callPhone(context, phone),
            icon: const Icon(Icons.call, color: C.green),
          ),
          IconButton.filledTonal(
            tooltip: 'WhatsApp',
            onPressed: () => openWhatsApp(context, phone, text: whatsappText),
            icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
          ),
        ],
      ]),
    );
  }
}
