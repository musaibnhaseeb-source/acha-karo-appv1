import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../screens/notifications_screen.dart';
import '../screens/history_screen.dart';
import '../screens/contact_screen.dart';
import '../screens/simulator_screen.dart';
import '../screens/settings_screen.dart';
import 'edit_profile_sheet.dart';

// Pilot scope — Friends/Groups deliberately hidden (parked as MVP2, per the current direction,
// not deleted — all the underlying code still exists, just not surfaced as an entry point here).
// Order: Edit Profile, Notifications, History, Contact, Settings.
class HomeSideSheet extends StatelessWidget {
  const HomeSideSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Drawer(
      backgroundColor: AppColors.bg2,
      width: 280,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Text('Menu', style: AppFonts.fraunces(size: 18, weight: FontWeight.w600)),
            ),
            const Divider(color: Color(0x1FF6F5EC), height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _SheetItem(
                    icon: '✏️',
                    label: 'Edit Profile',
                    onTap: () {
                      Navigator.of(context).pop();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const EditProfileSheet(),
                      );
                    },
                  ),
                  _SheetItem(
                    icon: '🔔',
                    label: 'Notifications',
                    trailing: _countBadge(state.notifications.where((n) => !n.read).length),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                    },
                  ),
                  _SheetItem(
                    icon: '📜',
                    label: 'History',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
                    },
                  ),
                  const Divider(color: Color(0x1FF6F5EC), height: 24),
                  _SheetItem(
                    icon: '💬',
                    label: 'Contact',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactScreen()));
                    },
                  ),
                  _SheetItem(
                    icon: '⚙️',
                    label: 'Settings',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),
                  const Divider(color: Color(0x1FF6F5EC), height: 24),
                  _SheetItem(
                    icon: '🧪',
                    label: 'Simulator (testing)',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SimulatorScreen()));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Shows an actual count (per the request: "show count in front"), not just a plain dot —
  // returns null when there's nothing to show, so _SheetItem/_SheetSubItem skip it cleanly.
  Widget? _countBadge(int count) {
    if (count <= 0) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: AppColors.rust, borderRadius: BorderRadius.circular(100)),
      child: Text('$count', style: AppFonts.plexMono(size: 9.5, weight: FontWeight.w700, color: Colors.white)),
    );
  }
}

class _SheetItem extends StatelessWidget {
  final String icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;
  const _SheetItem({required this.icon, required this.label, this.trailing, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: AppFonts.inter(size: 13.5, weight: FontWeight.w600))),
          if (trailing != null) trailing!,
        ]),
      ),
    );
  }
}
