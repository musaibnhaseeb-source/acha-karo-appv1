import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

// New — Profile is a real tab now, not a Home tile, per direction: "not a regression, a
// necessity." Home stays exactly as it was; Board/Achievements stays parked for later, per the
// explicit instruction not to bring that back yet. IndexedStack keeps both screens alive
// underneath (rather than rebuilding Profile from scratch every time you switch to it), same
// low-risk approach as everywhere else in this app that swaps content without losing state.
class MainTabScreen extends StatefulWidget {
  final int initialIndex; // 0 = Home (the app always starts here)
  const MainTabScreen({super.key, this.initialIndex = 0});
  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  late int _tabIndex = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // The floating bar sits over the content (screens pad their scroll views by the bar's
      // height, which Scaffold passes down as bottom MediaQuery padding).
      extendBody: true,
      body: IndexedStack(
        index: _tabIndex,
        children: const [HomeScreen(), ProfileScreen()],
      ),
      bottomNavigationBar: _FloatingNavBar(
        index: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

// Floating, rounded bottom bar (Musa: "dynamic and alive" instead of a flat strip). A gold pill
// slides to the active tab; the active icon scales up with a little bounce and its label turns
// gold. Implicit animations only — nothing runs while idle.
class _FloatingNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _FloatingNavBar({required this.index, required this.onTap});

  static const _items = [_NavItem(Icons.home_rounded, 'Home'), _NavItem(Icons.person_rounded, 'Profile')];
  static const _barHeight = 64.0;
  static const _anim = Duration(milliseconds: 320);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      // Floats clear of the screen edges and above the gesture bar.
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: _barHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 24, offset: const Offset(0, 8)),
            BoxShadow(color: AppColors.gold.withOpacity(0.08), blurRadius: 18),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bg2.withOpacity(0.86),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.gold.withOpacity(0.18)),
              ),
              child: LayoutBuilder(builder: (context, c) {
                final itemW = c.maxWidth / _items.length;
                return Stack(children: [
                  // Sliding active pill.
                  AnimatedPositioned(
                    duration: _anim,
                    curve: Curves.easeOutBack,
                    left: index * itemW + 10,
                    width: itemW - 20,
                    top: 8,
                    bottom: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(colors: [AppColors.gold.withOpacity(0.26), AppColors.gold.withOpacity(0.12)]),
                        border: Border.all(color: AppColors.gold.withOpacity(0.45)),
                        boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.18), blurRadius: 14)],
                      ),
                    ),
                  ),
                  Row(children: [
                    for (var i = 0; i < _items.length; i++)
                      Expanded(child: _NavButton(item: _items[i], active: i == index, onTap: () => onTap(i))),
                  ]),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;
  const _NavButton({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.gold : AppColors.textSoft.withOpacity(0.7);
    return Semantics(
      button: true,
      selected: active,
      label: '${item.label} tab',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: AppColors.gold.withOpacity(0.12),
        highlightColor: Colors.transparent,
        child: SizedBox.expand(
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedScale(
              scale: active ? 1.18 : 1.0,
              duration: _FloatingNavBar._anim,
              curve: active ? Curves.elasticOut : Curves.easeOut,
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: color),
                duration: _FloatingNavBar._anim,
                builder: (_, c, __) => Icon(item.icon, size: 24, color: c),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedDefaultTextStyle(
              duration: _FloatingNavBar._anim,
              style: AppFonts.inter(size: 12.5, weight: active ? FontWeight.w700 : FontWeight.w500, color: color),
              child: Text(item.label),
            ),
          ]),
        ),
      ),
    );
  }
}
