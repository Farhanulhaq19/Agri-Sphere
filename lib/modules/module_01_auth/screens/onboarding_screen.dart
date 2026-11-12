import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const List<List<String>> _slides = [
    ['Grow smarter.\nSell better.', 'One platform for farmers, buyers, agri experts and suppliers.'],
    ['Trade with trust.', 'List your crops and reach verified buyers directly.'],
    ['Ask the experts.', 'Get advisories and answers for your farm.'],
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              right: 24,
              bottom: 190,
              child: Container(
                width: 120,
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.sun.withOpacity(0.25),
                ),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.sun,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [ Image.asset('assets/img/2_mark_transparent.png', width: 28, height: 28, cacheWidth: 100, errorBuilder: (_, __, ___) => const Icon(Icons.eco_outlined, color: Colors.white, size: 18)),
                          SizedBox(width: 8),
                          Text(
                            'AgriSphere',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 170,
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _slides.length,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (_, i) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _slides[i][0],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _slides[i][1],
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(_slides.length, (i) {
                        final active = i == _page;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 6),
                          width: active ? 22 : 8,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active ? Colors.white : Colors.white54,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _chip(Icons.agriculture, 'Farmers'),
                        _chip(Icons.shopping_basket_outlined, 'Buyers'),
                        _chip(Icons.school_outlined, 'Experts'),
                      ],
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.dark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Get started',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            SizedBox(width: 6),
                            Icon(Icons.chevron_right, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        ),
                        child: const Text(
                          'I already have an account',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}