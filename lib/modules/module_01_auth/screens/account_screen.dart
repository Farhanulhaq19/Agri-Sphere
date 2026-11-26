import 'package:flutter/material.dart';
import 'package:agrisphere/core/widgets/ux.dart';
import 'package:agrisphere/modules/module_11_social/chat.dart';
import 'package:agrisphere/modules/module_11_social/favorites.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/api_service.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_01_auth/roles.dart';
import 'package:agrisphere/modules/module_01_auth/session_helper.dart';
import 'package:agrisphere/modules/module_01_auth/screens/change_password_screen.dart';
import 'package:agrisphere/modules/module_01_auth/screens/notifications_screen.dart';
import 'package:agrisphere/modules/module_01_auth/screens/role_gate_screen.dart';

/// One account page for every role: profile, my roles (switch / add / remove),
/// password, notifications and logout. It is a tab in the owner apps and a
/// pushed page from the farmer, supplier and expert homes.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  AuthSession? _s;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await ApiService.instance.me(); // refreshes the saved roles
    final s = await ApiService.instance.session();
    if (!mounted) return;
    if (s == null) {
      setState(() => _err = r.message.isEmpty ? 'Please log in again' : r.message);
      return;
    }
    setState(() {
      _s = s;
      _err = null;
      _name.text = s.name;
      _phone.text = s.phone;
    });
  }

  Future<void> _switch(String role) async {
    setState(() => _busy = true);
    final res = await ApiService.instance.switchRole(role);
    if (!mounted) return;
    if (res.success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleGateScreen()),
        (route) => false,
      );
    } else {
      setState(() => _busy = false);
      snack(context, res.message, error: true);
    }
  }

  Future<void> _addRole() async {
    final owned = _s!.roles.map(normalizeRole).toSet();
    final options = kRoles.where((r) => !owned.contains(r.value)).toList();
    if (options.isEmpty) {
      snack(context, 'You already have every role');
      return;
    }
    final picked = <String>{};
    final chosen = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('Add another role'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(tr('One account, many roles. Switch between them any time.'), style: TextStyle(color: C.grey, fontSize: 12)),
              const SizedBox(height: 12),
              ...options.map((r) {
                final on = picked.contains(r.value);
                return CheckboxListTile(
                  value: on,
                  activeColor: C.green,
                  contentPadding: EdgeInsets.zero,
                  secondary: RoleBadge(r.value, size: 40),
                  title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(r.desc, style: const TextStyle(fontSize: 11.5)),
                  onChanged: (v) => setM(() {
                    if (v == true) {
                      picked.add(r.value);
                    } else {
                      picked.remove(r.value);
                    }
                  }),
                );
              }),
              const SizedBox(height: 8),
              PrimaryButton(
                label: picked.isEmpty ? 'Pick a role' : 'Add ${picked.length} role(s)',
                onPressed: picked.isEmpty ? null : () => Navigator.pop(ctx, picked.toList()),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || chosen.isEmpty) return;
    setState(() => _busy = true);
    final res = await ApiService.instance.addRoles(chosen);
    if (!mounted) return;
    setState(() => _busy = false);
    snack(context, res.success ? 'Role added. Tap it to switch.' : res.message, error: !res.success);
    if (res.success) _load();
  }

  Future<void> _removeRole(String role) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Remove ${roleName(role)}?'),
        content: Text(tr('Your data stays safe. You can add this role again later.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Cancel'))),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('Remove'))),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ApiService.instance.removeRole(role);
    if (!mounted) return;
    snack(context, res.success ? 'Role removed' : res.message, error: !res.success);
    if (res.success) _load();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final res = await ApiService.instance.updateAccount(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    snack(context, res.success ? 'Profile saved' : res.message, error: !res.success);
    if (res.success) _load();
  }

  Widget _tile(IconData i, String t, String sub, VoidCallback onTap) => AppCard(
    onTap: onTap,
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: C.light, borderRadius: BorderRadius.circular(12)),
          child: Icon(i, color: C.green, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(t), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              Text(tr(sub), style: const TextStyle(fontSize: 11.5, color: C.grey)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: C.grey),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) {
      return Scaffold(
        backgroundColor: C.bg,
        body: Center(
          child: _err == null
              ? const CircularProgressIndicator(color: C.green)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_err!),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: () => logout(context), child: Text(tr('Back to login'))),
                  ],
                ),
        ),
      );
    }
    final active = normalizeRole(s.role);
    return Scaffold(
      backgroundColor: C.bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GreenHeader(
            title: s.name,
            subtitle: s.email,
            bottom: Align(
              alignment: Alignment.centerLeft,
              child: Pill('Active: ${roleName(s.role)}', color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(
                  'My roles',
                  trailing: TextButton.icon(
                    onPressed: _busy ? null : _addRole,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(tr('Add role')),
                  ),
                ),
                ...s.roles.map((r) {
                  final info = roleInfo(r);
                  final isActive = normalizeRole(r) == active;
                  return AppCard(
                    onTap: isActive || _busy ? null : () => _switch(r),
                    child: Row(
                      children: [
                        RoleBadge(info.value, size: 46),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(info.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              Text(isActive ? 'Currently active' : 'Tap to switch', style: TextStyle(fontSize: 11.5, color: isActive ? C.green : C.grey)),
                            ],
                          ),
                        ),
                        if (!isActive && s.roles.length > 1)
                          IconButton(
                            tooltip: tr('Remove role'),
                            icon: const Icon(Icons.close, size: 18, color: C.grey),
                            onPressed: _busy ? null : () => _removeRole(r),
                          ),
                        if (isActive) const Icon(Icons.check_circle, color: C.green),
                      ],
                    ),
                  );
                }),
                const SectionTitle('Profile'),
                field('Full name', _name, icon: Icons.person_outline),
                field('Phone', _phone, type: TextInputType.phone, icon: Icons.phone_outlined),
                PrimaryButton(label: tr('Save profile'), icon: Icons.check, loading: _busy, onPressed: _save),
                const SectionTitle('Account'),
                _tile(Icons.notifications_none, 'Notifications', 'Orders, offers, bookings, replies', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                }),
                _tile(Icons.forum_outlined, 'Messages', 'Chats with buyers, sellers and owners', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen()));
                }),
                _tile(Icons.favorite_border, 'Saved items', 'Produce, machines and warehouses you saved', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedScreen()));
                }),
                _tile(Icons.format_size, 'Text size', 'Make the app text bigger', () => showTextSizeSheet(context)),
                _tile(Icons.tour_outlined, 'App tour', 'See how AgriSphere works again', () => AppTour.show(context)),
                _tile(Icons.lock_reset, 'Change password', 'Keep your account secure', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
                }),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => logout(context),
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: Text(tr('Log out'), style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
