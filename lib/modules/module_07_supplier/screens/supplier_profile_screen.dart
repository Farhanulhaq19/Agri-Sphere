import 'package:flutter/material.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_01_auth/session_helper.dart';

class SupplierProfileScreen extends StatefulWidget {
  const SupplierProfileScreen({super.key});
  @override
  State<SupplierProfileScreen> createState() => _SupplierProfileScreenState();
}

class _SupplierProfileScreenState extends State<SupplierProfileScreen> {
  Map? _me;
  String? _err;
  bool _busy = false;
  final _biz = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _addr = TextEditingController();
  final _lic = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await AgriApi.get('/me') as Map;
      final p = (d['profile'] as Map?) ?? {};
      if (!mounted) return;
      setState(() {
        _me = d;
        _err = null;
        _biz.text = '${p['businessName'] ?? ''}';
        _phone.text = '${p['phone'] ?? ''}';
        _city.text = '${p['city'] ?? ''}';
        _addr.text = '${p['address'] ?? ''}';
        _lic.text = '${p['licenseNo'] ?? ''}';
      });
    } catch (e) {
      if (mounted) setState(() => _err = cleanErr(e));
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await AgriApi.put('/profile', {
        'businessName': _biz.text.trim(),
        'phone': _phone.text.trim(),
        'city': _city.text.trim(),
        'address': _addr.text.trim(),
        'licenseNo': _lic.text.trim(),
      });
      if (mounted) snack(context, 'Profile saved');
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_me == null) {
      return Scaffold(
        backgroundColor: C.bg,
        body: Center(
          child: _err == null
              ? const CircularProgressIndicator(color: C.green)
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_err!),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ]),
        ),
      );
    }
    final verified = ((_me!['profile'] as Map?)?['verified']) == true;
    return Scaffold(
      backgroundColor: C.bg,
      body: ListView(padding: EdgeInsets.zero, children: [
        GreenHeader(
          title: '${_me!['name']}',
          subtitle: '${_me!['email']}',
          bottom: Align(
            alignment: Alignment.centerLeft,
            child: Pill(verified ? 'Verified supplier' : 'Verification pending', color: Colors.white),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            field('Business name', _biz, icon: Icons.store_outlined),
            field('Phone', _phone, type: TextInputType.phone, icon: Icons.phone_outlined),
            field('City', _city, icon: Icons.location_city),
            field('Address', _addr, icon: Icons.location_on_outlined),
            field('Licence / NTN number', _lic, icon: Icons.badge_outlined),
            PrimaryButton(label: 'Save profile', icon: Icons.check, loading: _busy, onPressed: _save),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => logout(context),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Log out', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ]),
        ),
      ]),
    );
  }
}