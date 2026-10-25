import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/messaging.dart';
import '../../core/data/session.dart';
import '../../core/models/models.dart';
import '../../core/ui/theme.dart';

/// Shown while the store has not approved the account, or after it said no.
class WaitingScreen extends ConsumerWidget {
  const WaitingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final profile = session is Customer ? session.profile : null;
    final settings = ref.watch(settingsProvider).value;
    final t = Theme.of(context).textTheme;

    final (icon, color, title, message) = switch (profile?.status) {
      UserStatus.rejected => (
          Icons.info_outline,
          Colors.deepOrange,
          'Registration not approved',
          profile?.rejectReason?.isNotEmpty == true
              ? profile!.rejectReason!
              : 'The store could not approve your registration. You can correct your details and send them again.',
        ),
      UserStatus.blocked => (
          Icons.block,
          AppColors.danger,
          'Account blocked',
          'This account cannot place orders. Please contact the store.',
        ),
      _ => (
          Icons.hourglass_top,
          AppColors.green,
          'Waiting for approval',
          'Thanks, ${profile?.firstName ?? ''}! The store will check your details soon. We will send you a notification when your account is ready.',
        ),
    };

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(icon, size: 72, color: color),
              const SizedBox(height: 20),
              Text(title, textAlign: TextAlign.center, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: t.bodyLarge?.copyWith(color: Colors.black54)),
              if (profile != null && profile.status == UserStatus.pending) ...[
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    title: Text(profile.fullName),
                    subtitle: Text('${profile.mobile}\n${profile.address.oneLine}'),
                    isThreeLine: true,
                  ),
                ),
              ],
              const Spacer(),
              if (profile?.status == UserStatus.rejected)
                FilledButton(onPressed: () => context.go('/register'), child: const Text('Correct my details')),
              if (settings != null && settings.storePhone.isNotEmpty) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: settings.storePhone)),
                  icon: const Icon(Icons.call),
                  label: const Text('Call the store'),
                ),
              ],
              TextButton(
                onPressed: () async {
                  await Messaging.instance.unregister();
                  await ref.read(authRepositoryProvider).signOut();
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
