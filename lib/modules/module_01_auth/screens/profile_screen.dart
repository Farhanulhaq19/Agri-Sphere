import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String name;
  final String role;
  const ProfileScreen({super.key, this.name = 'User', this.role = 'Farmer'});

  static const List<List<dynamic>> _menu = [
    [Icons.person_outline, 'Edit profile', 'Name, email, farm location'],
    [Icons.location_on_outlined, 'Saved addresses', '2 addresses'],
    [Icons.notifications_none, 'Notifications', 'Orders, replies, advisories'],
    [Icons.tune, 'Settings', 'Language & privacy'],
  ];

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.home_outlined, color: AppColors.muted),
              const Icon(Icons.eco_outlined, color: AppColors.muted),
              const Icon(Icons.shopping_bag_outlined, color: AppColors.muted),
              const Icon(Icons.chat_bubble_outline, color: AppColors.muted),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.person_outline, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text('Profile',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: const CircleAvatar(
                          radius: 40,
                          backgroundColor: Color(0xFFE4F2E9),
                          child: Icon(Icons.person, size: 46, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_outlined,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(roleDisplay(role),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            _stat('6', 'Crops'),
                            _stat('48', 'Orders'),
                            _stat('4.8', 'Rating'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          children: _menu.map((m) {
                            return ListTile(
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE4F2E9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(m[0] as IconData,
                                    color: AppColors.primary, size: 20),
                              ),
                              title: Text(m[1] as String,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 14)),
                              subtitle: Text(m[2] as String,
                                  style: const TextStyle(
                                      fontSize: 11.5, color: AppColors.muted)),
                              trailing: const Icon(Icons.chevron_right,
                                  color: AppColors.muted),
                              onTap: () {},
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                          label: const Text('Log out',
                              style: TextStyle(
                                  color: Colors.redAccent, fontWeight: FontWeight.w700)),
                          onPressed: () async {
                            await ApiService.instance.logout();
                            if (!context.mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}