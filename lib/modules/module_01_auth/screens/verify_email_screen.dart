import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/auth_widgets.dart';
import 'profile_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _ctrl = TextEditingController();
  Timer? _timer;
  int _seconds = 30;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_seconds <= 1) {
        t.cancel();
        setState(() => _seconds = 0);
      } else {
        setState(() => _seconds--);
      }
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _verify() async {
    if (_loading) return;
    final code = _ctrl.text.trim();
    if (code.length != 6) {
      _toast('Enter the 6-digit code');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final res = await ApiService.instance.verifyEmail(email: widget.email, code: code);
    if (!mounted) return;
    setState(() => _loading = false);
    if (res.success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(
            name: (res.data?['name'] ?? 'User').toString(),
            role: (res.data?['role'] ?? 'Farmer').toString(),
          ),
        ),
        (route) => false,
      );
    } else {
      _toast(res.message);
    }
  }

  Future<void> _resend() async {
    if (_seconds > 0) return;
    final res = await ApiService.instance.sendEmailOtp(widget.email);
    if (!mounted) return;
    _toast(res.message);
    if (res.success) {
      setState(() => _seconds = 30);
      _tick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mm = '00:${_seconds.toString().padLeft(2, '0')}';
    return AuthScaffold(
      title: 'Verify your email',
      subtitle: 'Enter the 6-digit code sent to ${widget.email}',
      child: Column(
        children: [
          const SizedBox(height: 4),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: (v) {
              if (v.length == 6) _verify();
            },
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 12,
              color: AppColors.text,
            ),
            decoration: InputDecoration(
              hintText: '------',
              hintStyle: const TextStyle(color: AppColors.border, letterSpacing: 12, fontSize: 30),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Check your inbox (and the Spam folder). You can paste the code.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Didn't receive it?",
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _seconds == 0 ? _resend : null,
                child: Text(
                  _seconds == 0 ? 'Resend now' : 'Resend in $mm',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _seconds == 0 ? AppColors.primary : AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Verify & continue',
            icon: Icons.shield_outlined,
            loading: _loading,
            onPressed: _verify,
          ),
        ],
      ),
    );
  }
}