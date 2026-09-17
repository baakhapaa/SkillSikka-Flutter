import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _bg = Color(0xFFFAF9F6);
const _unreadBg = Color(0xFFF1F0ED);
const _ink = Color(0xFF111827);
const _gray = Color(0xFF6B7280);
const _divider = Color(0xFFE5E7EB);

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  static const _notifications = <_Notification>[
    _Notification(
      icon: 'assets/figma/notification/course-update.png',
      title: 'Course Update',
      message: 'New lesson available in Physical Chemistry Foundations',
      timeAgo: '2m ago',
      read: true,
    ),
    _Notification(
      icon: 'assets/figma/notification/achievement-unlocked.png',
      title: 'Achievement Unlocked',
      message: 'You earned a certificate in Basic Geometry!',
      timeAgo: '1h ago',
      read: true,
    ),
    _Notification(
      icon: 'assets/figma/notification/event-reminder.png',
      title: 'Event Reminder',
      message: 'Advanced Algebra Masterclass starts in 1 hour',
      timeAgo: '3h ago',
      read: true,
    ),
    _Notification(
      icon: 'assets/figma/notification/community-reply.png',
      title: 'Community Reply',
      message: 'Dr. Sarah Pathrin replied to your comment',
      timeAgo: '1d ago',
      read: false,
    ),
    _Notification(
      icon: 'assets/figma/notification/system-alert.png',
      title: 'System Alert',
      message: 'Your weekly learning report is ready',
      timeAgo: '1d ago',
      read: false,
    ),
    _Notification(
      icon: 'assets/figma/notification/course-quiz-results.png',
      title: 'Course Quiz Results',
      message: 'Python for Absolute Beginners - Quiz results available',
      timeAgo: '1d ago',
      read: false,
    ),
    _Notification(
      icon: 'assets/figma/notification/new-event-added.png',
      title: 'New Event Added',
      message: 'New event: React Native Workshop added to calendar',
      timeAgo: '1d ago',
      read: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildNavigationHeader(context),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: _notifications.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  thickness: 1,
                  color: _divider,
                ),
                itemBuilder: (context, index) {
                  return _buildNotificationRow(_notifications[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationHeader(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: _bg,
      child: Row(
        children: [
          // Back button (glassy circle)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: _ink,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'Notifications',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
  
  Widget _buildNotificationRow(_Notification n) {
    return Container(
      color: n.read ? _bg : _unreadBg,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(
              n.icon,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 40,
                height: 40,
                color: const Color(0xFFE5E7EB),
                child: const Icon(
                  Icons.notifications_none,
                  size: 20,
                  color: _gray,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Text block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  n.message,
                  style: GoogleFonts.figtree(
                    fontSize: 14,
                    height: 1.4,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  n.timeAgo,
                  style: GoogleFonts.figtree(
                    fontSize: 12,
                    color: _gray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notification {
  const _Notification({
    required this.icon,
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.read,
  });

  final String icon;
  final String title;
  final String message;
  final String timeAgo;

  final bool read;
}