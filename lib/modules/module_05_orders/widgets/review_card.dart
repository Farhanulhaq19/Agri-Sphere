import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

/// On a delivered order: the buyer rates it (stars + optional comment), or sees their rating.
class ReviewCard extends StatefulWidget {
  final Map order;
  final VoidCallback onChanged;
  const ReviewCard({super.key, required this.order, required this.onChanged});
  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  int _stars = 0;
  final _text = TextEditingController();
  bool _busy = false;

  static const _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_stars == 0) {
      snack(context, 'Tap the stars to rate', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await AgriApi.post('/orders/${widget.order['id']}/review', {'rating': _stars, 'text': _text.text.trim()});
      if (mounted) snack(context, 'Thank you for your review!');
      widget.onChanged();
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _starRow(int value, {ValueChanged<int>? onTap, double size = 34}) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          5,
          (i) => GestureDetector(
            onTap: onTap == null ? null : () => onTap(i + 1),
            child: AnimatedScale(
              scale: i < value ? 1.08 : 1,
              duration: const Duration(milliseconds: 150),
              child: Icon(i < value ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFF5A524), size: size),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    if (o['isBuyer'] != true || '${o['status']}' != 'delivered') return const SizedBox.shrink();
    if (o['reviewed'] == true) {
      return AppCard(
        child: Row(children: [
          const Icon(Icons.rate_review_outlined, color: C.green),
          const SizedBox(width: 10),
          Expanded(child: Text(tr('You rated this order'), style: const TextStyle(fontWeight: FontWeight.w700))),
          _starRow(toNum(o['myRating']).round(), size: 18),
        ]),
      );
    }
    return AppCard(
      child: Column(children: [
        Text(tr('How was your order?'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(tr('Your review helps other farmers and buyers'), style: const TextStyle(fontSize: 12, color: C.grey)),
        const SizedBox(height: 10),
        _starRow(_stars, onTap: (v) => setState(() => _stars = v)),
        SizedBox(
          height: 22,
          child: Text(_stars == 0 ? '' : tr(_labels[_stars]), style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w700)),
        ),
        TextField(
          controller: _text,
          maxLines: 2,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: tr('Quality, packing, delivery... (optional)'),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        PrimaryButton(label: tr('Submit review'), icon: Icons.send, loading: _busy, onPressed: _send),
      ]),
    );
  }
}
