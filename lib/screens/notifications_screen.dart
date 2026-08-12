import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import 'contact_screen.dart';
import 'history_screen.dart';

// Ported from #overlayNotifications / renderNotifications() in the original. Real infrastructure
// (model + screen + mark-read logic), but nothing in this Flutter port generates notifications
// yet — moderation and feedback flows aren't built here — so this will show the empty state in
// practice until those exist. Built now rather than blocked on them.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Real regression fixed here: this .reversed made sense when notifications were built
    // locally in oldest-to-newest order (appended as they happened) — but the real Supabase load
    // already fetches newest-first (order by created_at, ascending: false), so applying .reversed
    // on top of that flipped it right back to oldest-first, undoing the correct order.
    final sorted = state.notifications;
    final unreadCount = state.notifications.where((n) => !n.read).length;
    final subtitle = sorted.isEmpty
        ? "You're all caught up."
        : (unreadCount > 0 ? '$unreadCount unread of ${sorted.length}' : '${sorted.length} total');

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => Navigator.of(context).pop()),
        title: Text('Notifications', style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: wallpaperSwatches[context.watch<AppState>().wallpaperSwatchIndex])),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🔔 Notifications', style: AppFonts.fraunces(size: 22, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
                const SizedBox(height: 16),

                if (unreadCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: GestureDetector(
                      onTap: () {
                        context.read<AppState>().markAllNotificationsRead();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All caught up — every notification marked as read.')),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x29F6F5EC))),
                        alignment: Alignment.center,
                        child: Text('✓ Mark all as read', style: AppFonts.inter(size: 12.5, weight: FontWeight.w700)),
                      ),
                    ),
                  ),

                if (sorted.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(child: Text('Nothing here yet.', style: AppFonts.inter(size: 12, color: AppColors.textSoft))),
                  )
                else
                  ...sorted.map((n) => GestureDetector(
                        onTap: () {
                          context.read<AppState>().markNotificationRead(n.id);
                          // Real navigation now — both destinations exist. 'feedback' type
                          // notifications (a moderator responded) go to Contact, where responses
                          // are shown; 'taskActioned' (a deed was approved/rejected) goes to
                          // History, where the deed itself and its status are visible.
                          if (n.type == 'feedback') {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactScreen()));
                          } else {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.oliveCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: n.read ? const Color(0x24F6F5EC) : AppColors.gold.withOpacity(0.4)),
                            gradient: n.read ? null : LinearGradient(colors: [AppColors.gold.withOpacity(0.1), AppColors.oliveCard]),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(n.title, style: AppFonts.inter(size: 12.5, weight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(n.body, style: AppFonts.inter(size: 11.5, color: AppColors.textSoft, height: 1.4)),
                            const SizedBox(height: 4),
                            Text('Day ${n.day}${n.read ? '' : ' · tap to view'}', style: AppFonts.plexMono(size: 9, color: AppColors.textSoft)),
                          ]),
                        ),
                      )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
