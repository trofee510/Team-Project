import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../main.dart';
import '../auth/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Account section
          _SectionHeader(title: 'Account'),
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'Edit Style Preferences',
            subtitle: 'Update your aesthetics, body type, colors',
            onTap: () => context.push('/onboarding'),
          ),
          _SettingsTile(
            icon: Icons.diamond_outlined,
            title: 'Manage Subscription',
            subtitle: 'View or change your plan',
            onTap: () => context.push('/paywall'),
          ),

          const SizedBox(height: 16),

          // Notifications section
          _SectionHeader(title: 'Notifications'),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Daily Outfit Reminder',
            subtitle: 'Get styled every morning',
            trailing: Switch(
              value: false, // TODO: wire to user_profile.notificationsEnabled
              onChanged: (v) {
                // TODO: toggle notifications
              },
              activeColor: AppTheme.primary,
            ),
          ),
          _SettingsTile(
            icon: Icons.access_time,
            title: 'Reminder Time',
            subtitle: '7:30 AM', // TODO: wire to user_profile.notificationTime
            onTap: () async {
              // TODO: show time picker
            },
          ),

          const SizedBox(height: 16),

          // Data section
          _SectionHeader(title: 'Data'),
          _SettingsTile(
            icon: Icons.download,
            title: 'Export Wardrobe',
            subtitle: 'Download your wardrobe as JSON',
            onTap: () {
              // TODO: export data
            },
          ),

          const SizedBox(height: 16),

          // About section
          _SectionHeader(title: 'About'),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () => launchUrl(Uri.parse('https://grwm.app/terms')),
          ),
          _SettingsTile(
            icon: Icons.shield_outlined,
            title: 'Privacy Policy',
            onTap: () => launchUrl(Uri.parse('https://grwm.app/privacy')),
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'App Version',
            subtitle: '1.0.0',
          ),

          const SizedBox(height: 24),

          // Sign out
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: () async {
                if (!kDemoMode) {
                  await ref.read(authControllerProvider.notifier).signOut();
                }
                if (context.mounted) context.go('/auth');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Sign Out'),
            ),
          ),

          const SizedBox(height: 12),

          // Delete account
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Account?'),
                    content: const Text(
                        'This will permanently delete your account and all data. This cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          // TODO: delete account
                          Navigator.pop(ctx);
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
              child: Text('Delete Account',
                  style: TextStyle(color: Colors.red.shade300, fontSize: 14)),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.textSecondary),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))
          : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, size: 20) : null),
      onTap: onTap,
    );
  }
}
